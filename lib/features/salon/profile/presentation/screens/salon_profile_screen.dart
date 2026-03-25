import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../providers/salon_provider.dart';

class SalonProfileScreen extends StatefulWidget {
  const SalonProfileScreen({super.key});

  @override
  State<SalonProfileScreen> createState() => _SalonProfileScreenState();
}

class _SalonProfileScreenState extends State<SalonProfileScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _salon = {};
  String? _salonId;

  @override
  void initState() {
    super.initState();
    _loadSalonProfile();
  }

  Future<void> _loadSalonProfile() async {
    try {
      final provider = context.read<SalonProvider>();
      _salonId = provider.salonId;

      // Use cached data immediately so screen isn't blank
      if (provider.salonData != null) {
        _salon = provider.salonData!;
      }

      if (_salonId != null) {
        setState(() => _isLoading = _salon.isEmpty);
        final salonRes = await _api.get('${ApiConfig.salonDetail}/$_salonId');
        _salon = salonRes['data'] ?? _salon;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      // If we have cached data, show it despite the error
      if (_salon.isEmpty && mounted) ErrorHandler.handle(context, e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const ProfileSkeleton()
          : RefreshIndicator(
              onRefresh: _loadSalonProfile,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Cover image with salon info overlay
                  SliverAppBar(
                    expandedHeight: 220,
                    pinned: true,
                    title: const Text('My Salon'),
                    flexibleSpace: FlexibleSpaceBar(
                      background: _buildCoverImage(),
                    ),
                  ),

                  // Salon info card
                  SliverToBoxAdapter(
                    child: _buildSalonInfoCard(),
                  ),

                  // Menu tiles
                  SliverToBoxAdapter(
                    child: _buildMenuSection(),
                  ),

                  // Logout
                  SliverToBoxAdapter(
                    child: _buildLogoutButton(),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCoverImage() {
    final coverUrl = _salon['cover_image'] ?? _salon['coverImage'];
    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverUrl != null && coverUrl.toString().isNotEmpty)
          Image.network(
            ApiConfig.imageUrl(coverUrl) ?? coverUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildCoverPlaceholder(),
          )
        else
          _buildCoverPlaceholder(),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: AppColors.primaryDark,
      child: const Center(
        child: Icon(
          Icons.store,
          size: 64,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildSalonInfoCard() {
    final name = _salon['name'] ?? 'Your Salon';
    final address = _salon['address'] ?? '';
    final city = _salon['city'] ?? '';
    final state = _salon['state'] ?? '';
    final rating = _salon['rating_avg'] ?? _salon['ratingAvg'] ?? 0.0;
    final totalReviews = _salon['total_reviews'] ?? _salon['totalReviews'] ?? 0;
    final locationText = [address, city, state]
        .where((s) => s.toString().isNotEmpty)
        .join(', ');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Salon avatar and name
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.h4),
                    if (locationText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationText,
                              style: AppTextStyles.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          // Rating and status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip(
                Icons.star,
                (double.tryParse(rating.toString()) ?? 0.0).toStringAsFixed(1),
                '$totalReviews reviews',
                AppColors.ratingStar,
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.border,
              ),
              _buildInfoChip(
                Icons.circle,
                _salon['is_active'] == true ? 'Active' : 'Inactive',
                'Status',
                _salon['is_active'] == true
                    ? AppColors.success
                    : AppColors.textMuted,
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.border,
              ),
              _buildInfoChip(
                Icons.people_outline,
                '${_salon['gender_type'] ?? 'Unisex'}',
                'Type',
                AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage', style: AppTextStyles.h4),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.edit_outlined,
            title: 'Edit Salon Info',
            subtitle: 'Update name, address, and details',
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(
                  context,
                  '/salon/edit',
                  arguments: _salonId,
                );
              }
            },
          ),
          _ProfileMenuTile(
            icon: Icons.access_time_outlined,
            title: 'Operating Hours',
            subtitle: 'Set your working days and times',
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(
                  context,
                  '/salon/hours',
                  arguments: _salonId,
                );
              }
            },
          ),
          _ProfileMenuTile(
            icon: Icons.photo_library_outlined,
            title: 'Gallery',
            subtitle: 'Manage your salon photos',
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(
                  context,
                  '/salon/gallery',
                  arguments: _salonId,
                );
              }
            },
          ),
          _ProfileMenuTile(
            icon: Icons.local_offer_outlined,
            title: 'Amenities',
            subtitle: 'WiFi, AC, Parking and more',
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(
                  context,
                  '/salon/amenities',
                  arguments: _salonId,
                );
              }
            },
          ),
          const SizedBox(height: 20),
          const Text('Engagement', style: AppTextStyles.h4),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.chat_outlined,
            title: 'Chat Messages',
            subtitle: 'View and reply to customer chats',
            onTap: () {
              Navigator.pushNamed(context, '/salon/chat');
            },
          ),
          _ProfileMenuTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Earnings',
            subtitle: 'View revenue and transactions',
            onTap: () {
              Navigator.pushNamed(
                context,
                '/salon/earnings',
                arguments: _salonId,
              );
            },
          ),
          _ProfileMenuTile(
            icon: Icons.star_outline,
            title: 'Reviews',
            subtitle: 'See what customers are saying',
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(
                  context,
                  '/reviews',
                  arguments: _salonId,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              _ProfileMenuTile(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                titleColor: AppColors.error,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Logout'),
                      content:
                          const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/phone',
                        (route) => false,
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('Version 1.0.0', style: AppTextStyles.caption),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (titleColor ?? AppColors.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: titleColor ?? AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(color: titleColor),
        ),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }
}
