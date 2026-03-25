import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

/// Callback types for real-time chat events
typedef OnNewMessage = void Function(Map<String, dynamic> message);
typedef OnTypingIndicator = void Function(String userId, String userName, bool isTyping);
typedef OnMessagesRead = void Function(String readByUserId);
typedef OnRoomStatusChanged = void Function(bool isActive);

/// Callback for subscription status changes.
typedef OnSubscriptionStatus = void Function(bool isSubscribed, String? error);

/// Singleton service for managing Supabase Realtime chat subscriptions.
class SupabaseChatService {
  static final SupabaseChatService _instance = SupabaseChatService._internal();
  factory SupabaseChatService() => _instance;
  SupabaseChatService._internal();

  bool _initialized = false;
  SupabaseClient? _client;

  /// Prevents concurrent init calls from racing.
  Completer<bool>? _initCompleter;

  // Active channel subscriptions keyed by roomId
  final Map<String, RealtimeChannel> _channels = {};

  // Compile-time constants from --dart-define-from-file=.env
  static const _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Last init error for diagnostics.
  String? lastInitError;

  /// Initialize with Supabase credentials. Call once at app startup.
  Future<void> init({required String supabaseUrl, required String supabaseAnonKey}) async {
    if (_initialized) return;
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      lastInitError = 'Empty credentials';
      debugPrint('[SupabaseChat] Empty credentials, skipping init');
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _initialized = true;
      lastInitError = null;
      debugPrint('[SupabaseChat] Initialized successfully');
    } catch (e) {
      // Handle "already initialized" gracefully — reuse the existing client
      if (e.toString().contains('already') || e.toString().contains('initialized')) {
        try {
          _client = Supabase.instance.client;
          _initialized = true;
          lastInitError = null;
          debugPrint('[SupabaseChat] Already initialized, reusing existing client');
        } catch (e2) {
          lastInitError = e2.toString();
          debugPrint('[SupabaseChat] Failed to reuse client: $e2');
        }
      } else {
        lastInitError = e.toString();
        debugPrint('[SupabaseChat] Init error: $e');
      }
    }
  }

  /// Initialize using compile-time env first, then backend fallback.
  /// Safe to call from multiple places — concurrent calls are serialized.
  Future<void> initFromBackend() async {
    if (_initialized) return;

    // If another init is already in progress, wait for it
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    _initCompleter = Completer<bool>();

    try {
      // Try compile-time credentials first (instant, no network call)
      if (_envUrl.isNotEmpty && _envKey.isNotEmpty) {
        debugPrint('[SupabaseChat] Trying compile-time env: url=${_envUrl.substring(0, 20)}...');
        await init(supabaseUrl: _envUrl, supabaseAnonKey: _envKey);
        if (_initialized) return;
      } else {
        debugPrint('[SupabaseChat] No compile-time env vars found');
      }

      // Fallback: fetch from backend
      debugPrint('[SupabaseChat] Fetching config from backend...');
      try {
        final api = ApiService();
        final response = await api.get('/config/public', auth: false);
        final data = response['data'] ?? {};
        final url = data['supabase_url']?.toString() ?? '';
        final key = data['supabase_anon_key']?.toString() ?? '';

        if (url.isNotEmpty && key.isNotEmpty) {
          debugPrint('[SupabaseChat] Got config from backend: url=${url.substring(0, 20)}...');
          await init(supabaseUrl: url, supabaseAnonKey: key);
        } else {
          lastInitError = 'Backend returned empty Supabase config';
          debugPrint('[SupabaseChat] $lastInitError');
        }
      } catch (e) {
        lastInitError = 'Backend config fetch failed: $e';
        debugPrint('[SupabaseChat] $lastInitError');
      }
    } finally {
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.complete(_initialized);
      }
      _initCompleter = null;
    }
  }

  /// Whether the service is initialized and ready.
  bool get isReady => _initialized && _client != null;

  /// Diagnostic string for UI debugging.
  String get diagnosticInfo {
    if (isReady) return 'Supabase ready';
    if (lastInitError != null) return 'Init failed: $lastInitError';
    return 'Not initialized';
  }

  /// Extract the inner payload from a broadcast event.
  /// Supabase Dart client may wrap the payload: { event, payload: { ...data } }
  /// or deliver it flat: { ...data }. This handles both cases.
  static Map<String, dynamic> _unwrapPayload(Map<String, dynamic> raw) {
    // If the payload has a nested 'payload' key with a Map value, unwrap it
    if (raw.containsKey('payload') && raw['payload'] is Map) {
      return Map<String, dynamic>.from(raw['payload'] as Map);
    }
    return Map<String, dynamic>.from(raw);
  }

  /// Subscribe to a chat room's realtime channel.
  SupabaseChatSubscription subscribeToRoom({
    required String roomId,
    OnNewMessage? onNewMessage,
    OnTypingIndicator? onTyping,
    OnMessagesRead? onMessagesRead,
    OnRoomStatusChanged? onRoomStatus,
    OnSubscriptionStatus? onSubscriptionStatus,
  }) {
    if (!isReady) {
      debugPrint('[SupabaseChat] Not initialized, cannot subscribe');
      onSubscriptionStatus?.call(false, diagnosticInfo);
      return SupabaseChatSubscription._(roomId: roomId, service: this);
    }

    // Unsubscribe from existing channel for this room if any
    _unsubscribeRoom(roomId);

    final channelName = 'chat:$roomId';
    debugPrint('[SupabaseChat] Subscribing to channel: $channelName');
    final channel = _client!.channel(channelName);

    // Listen for new messages
    if (onNewMessage != null) {
      channel.onBroadcast(event: 'new_message', callback: (raw) {
        final payload = _unwrapPayload(raw);
        debugPrint('[SupabaseChat] >> Received new_message on $channelName: keys=${payload.keys.toList()}');
        onNewMessage(payload);
      });
    }

    // Listen for typing indicators
    if (onTyping != null) {
      channel.onBroadcast(event: 'typing', callback: (raw) {
        final payload = _unwrapPayload(raw);
        final userId = payload['user_id']?.toString() ?? '';
        final userName = payload['user_name']?.toString() ?? '';
        final isTyping = payload['is_typing'] == true;
        onTyping(userId, userName, isTyping);
      });
    }

    // Listen for read receipts
    if (onMessagesRead != null) {
      channel.onBroadcast(event: 'messages_read', callback: (raw) {
        final payload = _unwrapPayload(raw);
        final readBy = payload['read_by']?.toString() ?? '';
        onMessagesRead(readBy);
      });
    }

    // Listen for room status changes
    if (onRoomStatus != null) {
      channel.onBroadcast(event: 'room_status', callback: (raw) {
        final payload = _unwrapPayload(raw);
        final isActive = payload['is_active'] == true;
        onRoomStatus(isActive);
      });
    }

    channel.subscribe((status, error) {
      final statusStr = status.toString();
      debugPrint('[SupabaseChat] Channel $channelName subscribe status: $statusStr (error: $error)');

      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('[SupabaseChat] Channel $channelName SUBSCRIBED — ready to receive broadcasts');
        onSubscriptionStatus?.call(true, null);
      } else if (status == RealtimeSubscribeStatus.closed ||
                 status == RealtimeSubscribeStatus.channelError ||
                 status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('[SupabaseChat] Channel $channelName FAILED: $statusStr');
        onSubscriptionStatus?.call(false, 'Channel $statusStr${error != null ? ": $error" : ""}');
      }
    });

    _channels[roomId] = channel;

    return SupabaseChatSubscription._(roomId: roomId, service: this);
  }

  /// Subscribe to user-level channel for unread count updates.
  SupabaseChatSubscription subscribeToUserChannel({
    required String userId,
    required void Function(String roomId, int unreadCount) onUnreadUpdate,
    OnSubscriptionStatus? onSubscriptionStatus,
  }) {
    final channelKey = 'user:$userId';
    if (!isReady) {
      debugPrint('[SupabaseChat] Not initialized, cannot subscribe to user channel');
      onSubscriptionStatus?.call(false, diagnosticInfo);
      return SupabaseChatSubscription._(roomId: channelKey, service: this);
    }

    _unsubscribeRoom(channelKey);

    final channelName = 'chat:user:$userId';
    debugPrint('[SupabaseChat] Subscribing to user channel: $channelName');
    final channel = _client!.channel(channelName);

    channel.onBroadcast(event: 'unread_update', callback: (raw) {
      final payload = _unwrapPayload(raw);
      debugPrint('[SupabaseChat] >> Received unread_update on $channelName: keys=${payload.keys.toList()}');
      final roomId = payload['room_id']?.toString() ?? '';
      final count = (payload['unread_count'] is int)
          ? payload['unread_count'] as int
          : int.tryParse(payload['unread_count']?.toString() ?? '0') ?? 0;
      onUnreadUpdate(roomId, count);
    });

    channel.subscribe((status, error) {
      final statusStr = status.toString();
      debugPrint('[SupabaseChat] User channel $channelName status: $statusStr (error: $error)');

      if (status == RealtimeSubscribeStatus.subscribed) {
        onSubscriptionStatus?.call(true, null);
      } else if (status == RealtimeSubscribeStatus.closed ||
                 status == RealtimeSubscribeStatus.channelError ||
                 status == RealtimeSubscribeStatus.timedOut) {
        onSubscriptionStatus?.call(false, 'Channel $statusStr${error != null ? ": $error" : ""}');
      }
    });

    _channels[channelKey] = channel;
    return SupabaseChatSubscription._(roomId: channelKey, service: this);
  }

  /// Unsubscribe from a specific room channel.
  void _unsubscribeRoom(String roomId) {
    final channel = _channels.remove(roomId);
    if (channel != null && _client != null) {
      _client!.removeChannel(channel);
      debugPrint('[SupabaseChat] Unsubscribed from $roomId');
    }
  }

  /// Unsubscribe from a room (public API).
  void unsubscribe(String roomId) => _unsubscribeRoom(roomId);

  /// Unsubscribe from all active room channels.
  void unsubscribeAll() {
    for (final roomId in _channels.keys.toList()) {
      _unsubscribeRoom(roomId);
    }
  }

  /// Dispose the service entirely.
  void dispose() {
    unsubscribeAll();
    _initialized = false;
    _client = null;
  }
}

/// Handle for managing a single room subscription.
class SupabaseChatSubscription {
  final String roomId;
  final SupabaseChatService _service;

  SupabaseChatSubscription._({required this.roomId, required SupabaseChatService service})
      : _service = service;

  void unsubscribe() => _service.unsubscribe(roomId);
}
