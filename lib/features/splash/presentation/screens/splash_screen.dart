import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../services/supabase_chat_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/deep_link_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../salon/providers/salon_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }
  
  Future<void> _checkAuth() async {
    // Ensure Supabase is initialized for realtime chat
    if (!SupabaseChatService().isReady) {
      await SupabaseChatService().initFromBackend();
    }

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    await auth.checkAuthStatus();
    
    if (!mounted) return;
    
    switch (auth.state) {
      case AuthState.authenticated:
        // Initialize notifications after successful auth — await to ensure FCM token is saved
        await NotificationService().init();

        // Salon owner app — load salon data, redirect appropriately
        await context.read<SalonProvider>().loadSalonData();
        if (!mounted) return;
        final salonId = context.read<SalonProvider>().salonId;
        if (salonId == null) {
          // New user with no salon — go to create salon
          Navigator.pushReplacementNamed(context, '/salon/create');
        } else {
          Navigator.pushReplacementNamed(context, '/salon-home');
        }
        // Process any deep link that launched the app
        DeepLinkService().processPendingLink();
        break;
      case AuthState.profileIncomplete:
        Navigator.pushReplacementNamed(context, '/profile-setup');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/phone');
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SvgPicture.asset('assets/images/helohair-logo.svg', width: 64, height: 64),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'HeloHair',
              style: AppTextStyles.h1.copyWith(color: AppColors.white, fontSize: 36),
            ),
            const SizedBox(height: 8),
            Text(
              'Never wait at a salon again',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
