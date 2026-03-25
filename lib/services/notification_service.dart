import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import '../config/api_config.dart';
import '../core/constants/app_colors.dart';

/// Global navigator key for handling notification taps.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Standalone local notifications plugin — accessible from background handler too.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Android notification channel — must match backend channelId.
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'saloon_notifications',
  'Saloon Notifications',
  description: 'Booking updates, reminders, and promotions',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

/// Call this early (even from background handler) to ensure channel + plugin are ready.
Future<void> setupLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      if (payload != null && payload.startsWith('booking_id:')) {
        nav.pushNamed('/booking-detail', arguments: payload.replaceFirst('booking_id:', ''));
      } else if (payload == 'chat') {
        nav.pushNamed('/salon/chat');
      } else {
        nav.pushNamed('/notifications');
      }
    },
  );

  // Create the notification channel on Android
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(_androidChannel);
    await androidPlugin.requestNotificationsPermission();
  }
}

/// Show a local notification from any context (foreground handler, background handler, etc.)
Future<void> showLocalNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  try {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          showWhen: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
    debugPrint('[Notification] Shown: $title');
  } catch (e) {
    debugPrint('[Notification] Show failed: $e');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Lazy — only access on mobile, never on web
  FirebaseMessaging? _messaging;
  FirebaseMessaging get messaging => _messaging ??= FirebaseMessaging.instance;

  /// Stream controller for unread count updates.
  final _unreadController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadController.stream;
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  Timer? _pollTimer;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      // --- 1. Setup local notifications (channel + permissions) ---
      try {
        await setupLocalNotifications();
        debugPrint('[Notification] Local notifications setup complete');
      } catch (e) {
        debugPrint('[Notification] Local notifications setup failed: $e');
      }

      // --- 2. FCM setup ---
      try {
        final fcm = messaging;

        // Request permission (iOS mainly, Android 13+ handled by local notifications above)
        final settings = await fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

        // iOS foreground presentation
        await fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Get and save FCM token
        final token = await fcm.getToken();
        if (token != null) {
          debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
          await _saveToken(token);
        } else {
          debugPrint('[FCM] Token is null');
        }

        // Token refresh
        fcm.onTokenRefresh.listen((token) async {
          debugPrint('[FCM] Token refreshed');
          await _saveToken(token);
        });

        // Foreground messages — show local notification + in-app banner
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[FCM] Foreground message received: ${message.notification?.title}');
          _handleForegroundMessage(message);
        });

        // Background/terminated message taps
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

        // App opened from terminated state via notification tap
        final initialMessage = await fcm.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageTap(initialMessage);
        }

        debugPrint('[FCM] Setup complete');
      } catch (e) {
        debugPrint('[FCM] Setup failed: $e');
      }
    }

    // --- 3. Fetch unread count initially, poll less frequently since FCM handles realtime ---
    await fetchUnreadCount();
    // Poll every 2 minutes as a fallback (FCM foreground handler refreshes on each message)
    _pollTimer = Timer.periodic(const Duration(minutes: 2), (_) => fetchUnreadCount());
  }

  void dispose() {
    _pollTimer?.cancel();
    _unreadController.close();
  }

  Future<void> _saveToken(String token) async {
    try {
      await ApiService().put(ApiConfig.updateFcmToken, body: {'fcm_token': token});
      debugPrint('[FCM] Token saved to backend');
    } catch (e) {
      debugPrint('[FCM] Token save failed: $e');
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final res = await ApiService().get(ApiConfig.unreadCount);
      final count = (res['data']?['count'] ?? res['count'] ?? 0) as int;
      _unreadCount = count;
      _unreadController.add(count);
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Refresh unread count
    fetchUnreadCount();

    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;

    // Build payload for tap navigation
    String? payload;
    final bookingId = message.data['booking_id'];
    final type = message.data['type'] ?? '';
    if (bookingId != null) {
      payload = 'booking_id:$bookingId';
    } else if (type == 'chat') {
      payload = 'chat';
    }

    // Show system notification via flutter_local_notifications
    showLocalNotification(title: title, body: body, payload: payload);

    // Also show in-app banner
    _showInAppBanner(title, body, message.data);
  }

  void _showInAppBanner(String title, String body, Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _NotificationBanner(
        title: title,
        body: body,
        onDismiss: () {
          try { entry.remove(); } catch (_) {}
        },
        onTap: () {
          try { entry.remove(); } catch (_) {}
          _navigateFromData(data);
        },
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 4), () {
      try { entry.remove(); } catch (_) {}
    });
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('[FCM] Tap: ${message.data}');
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final bookingId = data['booking_id'];
    final type = data['type'] ?? '';

    if (bookingId != null) {
      nav.pushNamed('/booking-detail', arguments: bookingId.toString());
      return;
    }
    if (type == 'chat') {
      nav.pushNamed('/salon/chat');
      return;
    }
    nav.pushNamed('/notifications');
  }
}

/// In-app notification banner widget shown as an overlay.
class _NotificationBanner extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onTap,
          onVerticalDragEnd: (_) => onDismiss(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
