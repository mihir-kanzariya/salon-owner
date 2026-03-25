import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../config/api_config.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';

class ConsumerProfileScreen extends StatelessWidget {
  const ConsumerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;

          return ListView(
            children: [
              const SizedBox(height: 24),
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: user?.profilePhoto != null
                      ? NetworkImage(ApiConfig.imageUrl(user!.profilePhoto)!)
                      : null,
                  child: user?.profilePhoto == null
                      ? Text(
                          (user?.name ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 36, color: AppColors.white, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text(user?.name ?? 'User', style: AppTextStyles.h3)),
              Center(child: Text('+91 ${user?.phone ?? ''}', style: AppTextStyles.bodySmall)),
              const SizedBox(height: 24),

              // Menu items
              _ProfileTile(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                onTap: () => Navigator.pushNamed(context, '/edit-profile'),
              ),
              _ProfileTile(
                icon: Icons.favorite_outline,
                title: 'Favorite Salons',
                onTap: () => Navigator.pushNamed(context, '/favorites'),
              ),
              _ProfileTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
              _ProfileTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Help & Support'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Need help? Contact us:'),
                          SizedBox(height: 12),
                          Row(children: [
                            Icon(Icons.email_outlined, size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text('support@saloon.app'),
                          ]),
                          SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.phone_outlined, size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text('+91 1800-000-0000'),
                          ]),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _ProfileTile(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('About Saloon'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saloon - Salon Booking App', style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Text('Version 1.0.0'),
                          SizedBox(height: 8),
                          Text('Book your favorite salons, discover new styles, and manage your beauty appointments with ease.'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _ProfileTile(
                icon: Icons.logout,
                title: 'Logout',
                titleColor: AppColors.error,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/phone', (route) => false);
                    }
                  }
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('Version 1.0.0', style: AppTextStyles.caption),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? titleColor;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? AppColors.textSecondary),
        title: Text(title, style: AppTextStyles.bodyMedium.copyWith(color: titleColor)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
