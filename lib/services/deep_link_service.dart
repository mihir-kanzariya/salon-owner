import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notification_service.dart';

/// Handles incoming deep links (https://saloon.app/... and saloon://open/...)
/// and navigates to the appropriate screen.
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;
  DeepLinkService._();

  static const _channel = MethodChannel('app.saloon/deeplink');
  String? _pendingDeepLink;

  /// Call once during app startup to listen for incoming links.
  void init() {
    // Handle link that launched the app (cold start)
    _getInitialLink();

    // Handle links while app is running (warm start)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        _handleLink(call.arguments as String);
      }
    });
  }

  Future<void> _getInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null) _pendingDeepLink = link;
    } catch (_) {
      // Platform channel not set up yet — that's fine, we'll use Flutter's built-in handling
    }
  }

  /// Call after the user is authenticated and the navigator is ready.
  void processPendingLink() {
    if (_pendingDeepLink != null) {
      _handleLink(_pendingDeepLink!);
      _pendingDeepLink = null;
    }
  }

  void _handleLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // Supported paths:
    //   /salon/:id  → salon detail
    //   /booking/:id → booking detail
    final segments = uri.pathSegments;

    if (segments.length == 2 && segments[0] == 'salon') {
      nav.pushNamed('/salon-detail', arguments: segments[1]);
    } else if (segments.length == 2 && segments[0] == 'booking') {
      nav.pushNamed('/booking-detail', arguments: segments[1]);
    }
  }
}
