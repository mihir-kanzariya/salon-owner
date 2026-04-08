import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/widgets/language_toggle.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../providers/salon_provider.dart';
import '../../../salon_shell.dart';

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
                    title: Text(context.watch<LocaleProvider>().tr('my_salon')),
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
    final l = context.watch<LocaleProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.tr('manage'), style: AppTextStyles.h4),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.edit_outlined,
            title: l.tr('edit_salon'),
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
            title: l.tr('operating_hours'),
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
            title: l.tr('gallery'),
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
            title: l.tr('amenities'),
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
          _ProfileMenuTile(
            icon: Icons.block,
            title: l.tr('block_slots'),
            subtitle: l.tr('block_slots_desc'),
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(context, '/salon/slot-blocking', arguments: _salonId);
              }
            },
          ),
          _ProfileMenuTile(
            icon: Icons.calendar_month,
            title: l.tr('schedule_calendar'),
            subtitle: l.tr('schedule_calendar_desc'),
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(context, '/salon/calendar', arguments: _salonId);
              }
            },
          ),
          _ProfileMenuTile(
            icon: Icons.auto_awesome,
            title: l.tr('smart_scheduling'),
            subtitle: l.tr('smart_scheduling_desc'),
            onTap: () => _showSmartSchedulingDialog(l),
          ),
          const SizedBox(height: 20),
          Text(l.tr('engagement'), style: AppTextStyles.h4),
          const SizedBox(height: 12),
          _ProfileMenuTile(
            icon: Icons.analytics,
            title: l.tr('analytics'),
            subtitle: l.tr('analytics_desc'),
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(context, '/salon/analytics', arguments: _salonId);
              }
            },
          ),
          _ProfileMenuTile(
            icon: Icons.chat_outlined,
            title: l.tr('chat_messages'),
            subtitle: 'View and reply to customer chats',
            onTap: () {
              Navigator.pushNamed(context, '/salon/chat');
            },
          ),
          _ProfileMenuTile(
            icon: Icons.payment_outlined,
            title: l.tr('payment_setup'),
            subtitle: 'KYC, bank account & payout settings',
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(context, '/salon/payment-setup', arguments: _salonId);
              }
            },
          ),
          _ProfileMenuTile(
            icon: Icons.account_balance_wallet_outlined,
            title: l.tr('earnings_payouts'),
            subtitle: 'View revenue, commission & settlements',
            onTap: () {
              Navigator.pushNamed(context, '/salon/earnings', arguments: _salonId);
            },
          ),
          _ProfileMenuTile(
            icon: Icons.account_balance_outlined,
            title: l.tr('request_withdrawal'),
            subtitle: 'Transfer earnings to your bank',
            onTap: () {
              Navigator.pushNamed(context, '/salon/withdraw', arguments: {
                'salon_id': _salonId,
                'available_balance': 0.0, // Will be loaded on screen
              });
            },
          ),
          _ProfileMenuTile(
            icon: Icons.receipt_long_outlined,
            title: l.tr('transaction_history'),
            subtitle: 'All payments & settlement records',
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(context, '/salon/transactions', arguments: _salonId);
              }
            },
          ),
          _ProfileMenuTile(
            icon: Icons.emoji_events_outlined,
            title: l.tr('monthly_incentive'),
            subtitle: 'Track progress towards \u20B910,000 bonus',
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(context, '/salon/incentive', arguments: _salonId);
              }
            },
          ),
          _ProfileMenuTile(
            icon: Icons.people_outline,
            title: l.tr('team_members'),
            subtitle: 'Manage stylists & staff',
            onTap: () => SalonShell.switchToTab(3),
          ),
          _ProfileMenuTile(
            icon: Icons.star_outline,
            title: l.tr('salon_reviews'),
            subtitle: 'See what customers are saying',
            onTap: () {
              if (_salonId != null) {
                Navigator.pushNamed(context, '/reviews', arguments: _salonId);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSmartSchedulingDialog(LocaleProvider l) {
    final settings = _salon['booking_settings'] ?? {};
    bool enabled = settings['smart_slot_enabled'] ?? true;
    double discount = (settings['smart_slot_discount'] ?? 10).toDouble();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(l.tr('smart_scheduling'), style: AppTextStyles.h4),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.tr('smart_scheduling_desc'), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: Text(l.tr('smart_slot_enabled'), style: AppTextStyles.bodyMedium),
                  value: enabled,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setDialogState(() => enabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (enabled) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.tr('smart_slot_discount_label'), style: AppTextStyles.bodyMedium),
                      Text('${discount.toInt()}%', style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
                    ],
                  ),
                  Slider(
                    value: discount,
                    min: 5,
                    max: 25,
                    divisions: 4,
                    label: '${discount.toInt()}%',
                    activeColor: AppColors.primary,
                    onChanged: (v) => setDialogState(() => discount = v),
                  ),
                  Text('5% — 25%', style: AppTextStyles.caption),
                ],
                const SizedBox(height: 20),
                // Explanation section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.tr('smart_how_it_works'), style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _smartBenefitRow(l.tr('smart_benefit_1')),
                      const SizedBox(height: 6),
                      _smartBenefitRow(l.tr('smart_benefit_2')),
                      const SizedBox(height: 6),
                      _smartBenefitRow(l.tr('smart_benefit_3')),
                      const SizedBox(height: 6),
                      _smartBenefitRow(l.tr('smart_benefit_4')),
                    ],
                  ),
                ),
                // Stats preview when enabled
                if (enabled) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current discount: ${discount.toInt()}% off on smart slots',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Builder(builder: (_) {
                          const examplePrice = 300;
                          final discounted = (examplePrice * (1 - discount / 100)).round();
                          return Text(
                            l.tr('smart_example')
                                .replaceAll('{price}', '$examplePrice')
                                .replaceAll('{discounted}', '$discounted'),
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.tr('cancel'))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _api.put('${ApiConfig.salonDetail}/$_salonId', body: {
                    'booking_settings': {
                      'smart_slot_enabled': enabled,
                      'smart_slot_discount': discount.toInt(),
                    },
                  });
                  _loadSalonProfile();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Smart scheduling updated'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(l.tr('save'), style: const TextStyle(color: AppColors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smartBenefitRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('\u2022 ', style: TextStyle(fontSize: 13, height: 1.4)),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(height: 1.4))),
      ],
    );
  }

  Widget _buildLogoutButton() {
    final l = context.watch<LocaleProvider>();
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
                title: l.tr('logout'),
                subtitle: 'Sign out of your account',
                titleColor: AppColors.error,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(l.tr('logout')),
                      content:
                          const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l.tr('cancel')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            l.tr('logout'),
                            style: const TextStyle(color: AppColors.error),
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
