import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../services/api_service.dart';
import '../../../../../services/notification_service.dart';
import '../../../../../config/api_config.dart';
import '../../../salon_shell.dart';
import '../../../providers/salon_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<dynamic> _todayBookings = [];
  String? _activeSalonId;
  StreamSubscription<int>? _unreadSub;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _unreadCount = NotificationService().unreadCount;
    _unreadSub = NotificationService().unreadCountStream.listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      setState(() => _isLoading = true);

      final sp = context.read<SalonProvider>();
      _activeSalonId = sp.salonId;

      if (_activeSalonId != null) {
        final queryParams = <String, dynamic>{};
        if (sp.isStylist && sp.memberId != null) {
          queryParams['stylist_member_id'] = sp.memberId!;
        }

        // Load salon stats
        final statsRes = await _api.get(
          '${ApiConfig.salonDetail}/$_activeSalonId/stats',
          queryParams: queryParams.isNotEmpty ? queryParams : null,
        );
        _stats = statsRes['data'] ?? {};

        // Load today's bookings
        final bookingParams = <String, dynamic>{
          'date': DateTime.now().toIso8601String().split('T')[0],
        };
        if (sp.isStylist && sp.memberId != null) {
          bookingParams['stylist_member_id'] = sp.memberId!;
        }
        final bookingsRes = await _api.get(
          '${ApiConfig.bookings}/salon/$_activeSalonId',
          queryParams: bookingParams,
        );
        _todayBookings = bookingsRes['data'] ?? [];
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e);
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await Navigator.pushNamed(context, '/notifications');
              NotificationService().fetchUnreadCount();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const DashboardSkeleton()
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Grid
                    const Text('Today\'s Overview', style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _StatCard(
                          title: 'Today\'s Bookings',
                          value: '${_stats['today_bookings'] ?? _todayBookings.length}',
                          icon: Icons.calendar_today,
                          color: AppColors.primary,
                        ),
                        _StatCard(
                          title: 'Today\'s Revenue',
                          value: '\u20B9${_stats['today_revenue'] ?? 0}',
                          icon: Icons.currency_rupee,
                          color: AppColors.success,
                        ),
                        _StatCard(
                          title: 'Pending',
                          value: '${_stats['pending_bookings'] ?? 0}',
                          icon: Icons.pending_actions,
                          color: AppColors.accent,
                        ),
                        _StatCard(
                          title: 'Rating',
                          value: (double.tryParse(_stats['rating_avg']?.toString() ?? '') ?? 0.0).toStringAsFixed(1),
                          icon: Icons.star,
                          color: AppColors.ratingStar,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions
                    const Text('Quick Actions', style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final sp = context.read<SalonProvider>();
                        if (sp.isStylist) {
                          return Row(
                            children: [
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.schedule_outlined,
                                  label: 'Availability',
                                  onTap: () {
                                    if (sp.memberId != null) {
                                      Navigator.pushNamed(context, '/salon/stylist-availability', arguments: sp.memberId);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: 'Earnings',
                                  onTap: () => Navigator.pushNamed(context, '/salon/earnings', arguments: {
                                    'salon_id': _activeSalonId,
                                    'stylist_member_id': sp.memberId,
                                  }),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.chat_outlined,
                                  label: 'Chat',
                                  onTap: () => SalonShell.switchToTab(3),
                                ),
                              ),
                            ],
                          );
                        }
                        if (sp.isReceptionist) {
                          return Row(
                            children: [
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Bookings',
                                  onTap: () => SalonShell.switchToTab(1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: 'Earnings',
                                  onTap: () => Navigator.pushNamed(context, '/salon/earnings', arguments: _activeSalonId),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.chat_outlined,
                                  label: 'Chat',
                                  onTap: () => SalonShell.switchToTab(3),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.add_circle_outline,
                                label: 'Add Service',
                                onTap: () => Navigator.pushNamed(context, '/salon/add-service', arguments: _activeSalonId),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.person_add_outlined,
                                label: 'Add Stylist',
                                onTap: () => Navigator.pushNamed(context, '/salon/add-stylist', arguments: _activeSalonId),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.account_balance_wallet_outlined,
                                label: 'Earnings',
                                onTap: () => Navigator.pushNamed(context, '/salon/earnings', arguments: _activeSalonId),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Today's Bookings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Today\'s Bookings', style: AppTextStyles.h3),
                        TextButton(
                          onPressed: () => SalonShell.switchToTab(1),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_todayBookings.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.event_available, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 8),
                            const Text('No bookings today', style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_todayBookings.length, (index) {
                        final booking = _todayBookings[index];
                        final customer = booking['customer'];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                (customer?['name'] ?? 'C')[0].toUpperCase(),
                                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                            title: Text(customer?['name'] ?? 'Customer', style: AppTextStyles.labelLarge),
                            subtitle: Text('${booking['start_time']} - ${booking['end_time']}', style: AppTextStyles.caption),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(booking['status']).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatStatus(booking['status'] ?? ''),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _getStatusColor(booking['status'])),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed': return AppColors.primary;
      case 'in_progress': return AppColors.accent;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textMuted;
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.h3.copyWith(color: color)),
          Text(title, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.labelMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
