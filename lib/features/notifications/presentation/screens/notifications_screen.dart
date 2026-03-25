import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../services/api_service.dart';
import '../../../../config/api_config.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _isLoading = true);
      final response = await _api.get(ApiConfig.notifications);
      _notifications = response['data'] ?? [];
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.put('${ApiConfig.notifications}/read-all');
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
    } catch (_) {}
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'booking_created': return Icons.calendar_today;
      case 'booking_confirmed': return Icons.check_circle;
      case 'booking_cancelled': return Icons.cancel;
      case 'booking_reminder': return Icons.alarm;
      case 'booking_completed': return Icons.done_all;
      case 'chat_message': return Icons.chat_bubble;
      case 'payment_received': return Icons.payment;
      case 'payment_reminder': return Icons.account_balance_wallet;
      case 'review_reminder': return Icons.star;
      case 'review_request': return Icons.rate_review;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read', style: TextStyle(color: AppColors.white, fontSize: 13)),
          ),
        ],
      ),
      body: _isLoading
          ? const SkeletonList(child: NotificationItemSkeleton(), count: 6)
          : _notifications.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.notifications_none,
                  title: 'No notifications',
                  subtitle: 'You\'re all caught up!',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['is_read'] == true;

                      return Container(
                        color: isRead ? null : AppColors.primary.withValues(alpha: 0.03),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isRead ? AppColors.softSurface : AppColors.primary.withValues(alpha: 0.1),
                            child: Icon(
                              _iconForType(n['type'] ?? 'general'),
                              color: isRead ? AppColors.textMuted : AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            n['title'] ?? '',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(n['body'] ?? '', style: AppTextStyles.caption, maxLines: 2),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
