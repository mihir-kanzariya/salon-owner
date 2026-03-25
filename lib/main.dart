import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/storage_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/consumer/home/presentation/providers/home_provider.dart';
import 'features/salon/providers/salon_provider.dart';
import 'features/auth/presentation/screens/phone_screen.dart';
import 'features/auth/presentation/screens/otp_screen.dart';
import 'features/auth/presentation/screens/profile_setup_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/consumer/salon_detail/presentation/screens/salon_detail_screen.dart';
import 'features/consumer/booking/presentation/screens/booking_screen.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';
import 'features/reviews/presentation/screens/reviews_screen.dart';
import 'features/reviews/presentation/screens/submit_review_screen.dart';
import 'features/consumer/consumer_shell.dart';
import 'features/consumer/booking_detail/presentation/screens/booking_detail_screen.dart';
import 'features/consumer/booking/presentation/screens/booking_success_screen.dart';
// Salon owner imports
import 'features/salon/salon_shell.dart';
import 'features/salon/profile/presentation/screens/create_salon_screen.dart';
import 'features/salon/profile/presentation/screens/edit_salon_screen.dart';
import 'features/salon/services/presentation/screens/add_service_screen.dart';
import 'features/salon/team/presentation/screens/add_stylist_screen.dart';
import 'features/salon/team/presentation/screens/stylist_availability_screen.dart';
import 'features/salon/earnings/presentation/screens/earnings_screen.dart';
import 'features/salon/earnings/presentation/screens/withdrawal_screen.dart';
import 'features/salon/earnings/presentation/screens/transactions_screen.dart';
import 'features/salon/onboarding/presentation/screens/payment_setup_screen.dart';
import 'features/consumer/payment/presentation/screens/payment_screen.dart';
import 'features/consumer/favorites/presentation/screens/favorites_screen.dart';
import 'features/consumer/search/presentation/screens/search_screen.dart';
import 'features/consumer/profile/presentation/screens/edit_profile_screen.dart';
import 'features/salon/profile/presentation/screens/operating_hours_screen.dart';
import 'features/salon/profile/presentation/screens/gallery_screen.dart';
import 'features/salon/profile/presentation/screens/amenities_screen.dart';
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

      // Setup local notifications early so the channel exists for background messages
      await setupLocalNotifications();

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[Firebase] Init error: $e');
    }
  }

  // Initialize connectivity monitoring
  await ConnectivityService().init();

  // Initialize Supabase from backend config (non-blocking — will retry in splash)
  SupabaseChatService().initFromBackend();

  // Initialize deep link handling
  DeepLinkService().init();

  runApp(const SaloonApp());
}

class SaloonApp extends StatelessWidget {
  const SaloonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => SalonProvider()),
      ],
      child: MaterialApp(
        title: 'Saloon',
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
      // Common routes
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/phone':
        return SlidePageRoute(child: const PhoneScreen());
      case '/otp':
        return SlidePageRoute(child: const OtpScreen());
      case '/profile-setup':
        return SlidePageRoute(child: const ProfileSetupScreen());
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

      // Consumer routes
      case '/home':
        return SlidePageRoute(child: const ConsumerShell());
      case '/salon-detail':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: SalonDetailScreen(salonId: salonId));
      case '/booking':
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) return _notFoundRoute();
        return SlidePageRoute(
          child: BookingScreen(
            salonId: args['salon_id'],
            serviceIds: List<String>.from(args['service_ids']),
            totalDuration: args['total_duration'],
            totalPrice: args['total_price'],
            salonName: args['salon_name'] ?? '',
            members: args['members'] ?? [],
          ),
        );

      case '/booking-success':
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) return _notFoundRoute();
        return SlidePageRoute(
          child: BookingSuccessScreen(
            bookingId: args['booking_id'],
            salonName: args['salon_name'] ?? '',
            date: args['date'] ?? '',
            time: args['time'] ?? '',
            stylistName: args['stylist_name'] ?? 'Any Stylist',
            totalPrice: (args['total_price'] as num?)?.toDouble() ?? 0,
            serviceCount: args['service_count'] ?? 0,
          ),
        );
      case '/booking-detail':
        final bookingId = settings.arguments as String? ?? '';
        if (bookingId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: BookingDetailScreen(bookingId: bookingId));
      case '/submit-review':
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) return _notFoundRoute();
        return SlidePageRoute(
          child: SubmitReviewScreen(
            bookingId: args['booking_id'],
            salonId: args['salon_id'],
            salonName: args['salon_name'],
            stylistId: args['stylist_id'],
          ),
        );

      case '/favorites':
        return SlidePageRoute(child: const FavoritesScreen());
      case '/search':
        return SlidePageRoute(child: const SearchScreen());
      case '/edit-profile':
        return SlidePageRoute(child: const EditProfileScreen());

      // Salon owner routes
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
        return SlidePageRoute(child: const AddStylistScreen());
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
      case '/salon/payment-setup':
        final salonId = settings.arguments as String? ?? '';
        if (salonId.isEmpty) return _notFoundRoute();
        return SlidePageRoute(child: PaymentSetupScreen(salonId: salonId));

      // Payment routes
      case '/payment':
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) return _notFoundRoute();
        return SlidePageRoute(
          child: PaymentScreen(
            bookingId: args['booking_id'],
            amount: (args['amount'] as num).toDouble(),
            salonName: args['salon_name'] ?? 'Salon',
            paymentType: args['payment_type'] ?? 'full',
          ),
        );

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
