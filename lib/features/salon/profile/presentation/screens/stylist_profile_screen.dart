import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../providers/salon_provider.dart';

class StylistProfileScreen extends StatefulWidget {
  const StylistProfileScreen({super.key});

  @override
  State<StylistProfileScreen> createState() => _StylistProfileScreenState();
}

class _StylistProfileScreenState extends State<StylistProfileScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => _isLoading = true);
      final sp = context.read<SalonProvider>();
      if (sp.memberId != null) {
        final res = await _api.get('${ApiConfig.stylists}/${sp.memberId}/profile');
        _profile = res['data'] ?? {};
      }
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SalonProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const LoadingWidget()
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: _profile['user']?['profile_photo'] != null
                                ? NetworkImage(ApiConfig.imageUrl(_profile['user']['profile_photo']) ?? '')
                                : null,
                            child: _profile['user']?['profile_photo'] == null
                                ? Text(
                                    (_profile['user']?['name'] ?? 'S')[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _profile['user']?['name'] ?? (sp.isStylist ? 'Stylist' : 'Staff'),
                            style: AppTextStyles.h3,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: (sp.isReceptionist ? AppColors.accent : AppColors.primary).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatRole(sp.myRole),
                              style: AppTextStyles.labelMedium.copyWith(
                                color: sp.isReceptionist ? AppColors.accent : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Menu items
                    _ProfileMenuTile(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profile',
                      subtitle: 'Update your name and photo',
                      onTap: () => Navigator.pushNamed(context, '/edit-profile'),
                    ),
                    if (sp.isStylist) ...[
                      _ProfileMenuTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'My Earnings',
                        subtitle: 'View your earnings',
                        onTap: () {
                          if (sp.salonId != null) {
                            Navigator.pushNamed(
                              context,
                              '/salon/earnings',
                              arguments: {
                                'salon_id': sp.salonId,
                                'stylist_member_id': sp.memberId,
                              },
                            );
                          }
                        },
                      ),
                      _ProfileMenuTile(
                        icon: Icons.star_outline,
                        title: 'My Reviews',
                        subtitle: 'Reviews from your customers',
                        onTap: () {
                          if (sp.salonId != null) {
                            Navigator.pushNamed(
                              context,
                              '/reviews',
                              arguments: {
                                'salon_id': sp.salonId,
                                'stylist_member_id': sp.memberId,
                              },
                            );
                          }
                        },
                      ),
                      _ProfileMenuTile(
                        icon: Icons.schedule_outlined,
                        title: 'My Availability',
                        subtitle: 'Manage your schedule',
                        onTap: () {
                          if (sp.memberId != null) {
                            Navigator.pushNamed(
                              context,
                              '/salon/stylist-availability',
                              arguments: sp.memberId,
                            );
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text('Logout'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Version 1.0.0',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatRole(String? role) {
    if (role == null || role.isEmpty) return 'Staff';
    return role[0].toUpperCase() + role.substring(1);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                context.read<SalonProvider>().clear();
                Navigator.pushNamedAndRemoveUntil(context, '/phone', (_) => false);
              }
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: AppTextStyles.labelLarge),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
