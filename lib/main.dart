import 'core/i18n/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/storage_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/salon/providers/salon_provider.dart';
import 'features/auth/presentation/screens/phone_screen.dart';
import 'features/auth/presentation/screens/otp_screen.dart';
import 'features/auth/presentation/screens/profile_setup_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';
import 'features/reviews/presentation/screens/reviews_screen.dart';
// Salon owner imports
import 'features/salon/salon_shell.dart';
import 'features/salon/profile/presentation/screens/create_salon_screen.dart';
import 'features/salon/profile/presentation/screens/edit_salon_screen.dart';
import 'features/salon/services/presentation/screens/add_service_screen.dart';
import 'features/salon/team/presentation/screens/add_stylist_screen.dart';
import 'features/salon/team/presentation/screens/stylist_availability_screen.dart';
import 'features/salon/earnings/presentation/screens/earnings_screen.dart';
import 'features/salon/earnings/presentation/screens/withdrawal_screen.dart';
import 'features/salon/earnings/presentation/screens/bank_account_setup_screen.dart';
import 'features/salon/earnings/presentation/screens/transactions_screen.dart';
import 'features/salon/onboarding/presentation/screens/payment_setup_screen.dart';
import 'features/salon/profile/presentation/screens/operating_hours_screen.dart';
import 'features/salon/profile/presentation/screens/gallery_screen.dart';
import 'features/salon/profile/presentation/screens/amenities_screen.dart';
import 'features/salon/incentive/presentation/screens/incentive_screen.dart';
import 'features/chat/presentation/screens/chat_list_screen.dart';
import 'services/supabase_chat_service.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/deep_link_service.dart';
import 'core/widgets/offline_banner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// Top-level background message handler — required for FCM background notifications.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}
  }
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().init();

  // Initialize Firebase (skip on web — not configured)
  if (!kIsWeb) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      debugPrint('[Firebase] Initialized successfully');
      await setupLocalNotifications();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[Firebase] Init error: $e');
    }
  }

  await ConnectivityService().init();
  SupabaseChatService().initFromBackend();
  DeepLinkService().init();

  runApp(const HeloHairBusinessApp());
}

class HeloHairBusinessApp extends StatelessWidget {
  const HeloHairBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SalonProvider()),
      ],
      child: MaterialApp(
        title: 'HeloHair Business',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        initialRoute: '/',
        onGenerateRoute: _onGenerateRoute,
        builder: (context, child) => OfflineBanner(child: child!),
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth routes
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/phone':
        return SlidePageRoute(child: const PhoneScreen());
      case '/otp':
        return SlidePageRoute(child: const OtpScreen());
      case '/profile-setup':
        return SlidePageRoute(child: const ProfileSetupScreen());

      // Common routes
      case '/notifications':
        return SlidePageRoute(child: const NotificationsScreen());
      case '/reviews':
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return SlidePageRoute(
            child: ReviewsScreen(
              salonId: args['salon_id'] as String,
              stylistMemberId: args['stylist_member_id'] as String?,
            ),
          );
        }
        final salonId = args as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: ReviewsScreen(salonId: salonId));

      // Salon owner routes
      case '/home': // Redirect /home to salon-home for this app
      case '/salon-home':
        return SlidePageRoute(child: const SalonShell());
      case '/salon/create':
        return SlidePageRoute(child: const CreateSalonScreen());
      case '/salon/edit':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: EditSalonScreen(salonId: salonId));
      case '/salon/add-service':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: AddServiceScreen(salonId: salonId));
      case '/salon/edit-service':
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) return _notFoundRoute();
        return SlidePageRoute(
          child: AddServiceScreen(
            salonId: args['salon_id'],
            serviceId: args['service_id'],
          ),
        );
      case '/salon/add-stylist':
        final args = settings.arguments;
        if (args is String) {
          return SlidePageRoute(child: AddStylistScreen(salonId: args));
        } else if (args is Map<String, dynamic>) {
          return SlidePageRoute(
            child: AddStylistScreen(
              salonId: args['salon_id'],
              stylistId: args['stylist_id'],
              existingStylist: args,
            ),
          );
        }
        return _notFoundRoute(); // salonId required
      case '/salon/stylist-availability':
        final stylistId = settings.arguments as String? ?? '';
        if (stylistId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: StylistAvailabilityScreen(stylistId: stylistId));
      case '/salon/earnings':
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return SlidePageRoute(
            child: EarningsScreen(
              salonId: args['salon_id'] as String,
              stylistMemberId: args['stylist_member_id'] as String?,
            ),
          );
        }
        final salonId = args as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: EarningsScreen(salonId: salonId));
      case '/salon/hours':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: OperatingHoursScreen(salonId: salonId));
      case '/salon/gallery':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: GalleryScreen(salonId: salonId));
      case '/salon/amenities':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: AmenitiesScreen(salonId: salonId));
      case '/salon/chat':
        return SlidePageRoute(child: const ChatListScreen());
      case '/salon/withdraw':
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) return _notFoundRoute();
        return SlidePageRoute(
          child: WithdrawalScreen(
            salonId: args['salon_id'],
            availableBalance: (args['available_balance'] as num).toDouble(),
          ),
        );
      case '/salon/transactions':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: TransactionsScreen(salonId: salonId));
      case '/salon/bank-account':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: BankAccountSetupScreen(salonId: salonId));
      case '/salon/payment-setup':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: PaymentSetupScreen(salonId: salonId));
      case '/salon/incentive':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: IncentiveScreen(salonId: salonId));

      default:
        return _notFoundRoute();
    }
  }

  static Route<dynamic> _notFoundRoute() {
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(child: Text('Page not found')),
      ),
    );
  }
}

class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SlidePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 250),
        );
}
