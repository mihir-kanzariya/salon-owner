import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class WeeklyEarningsCard extends StatelessWidget {
  final double revenue;
  final double commission;
  final double net;
  final int bookingCount;
  final String? nextPayoutDate;
  final VoidCallback onViewEarnings;

  const WeeklyEarningsCard({
    super.key,
    required this.revenue,
    required this.commission,
    required this.net,
    required this.bookingCount,
    this.nextPayoutDate,
    required this.onViewEarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('This Week\'s Earnings', style: AppTextStyles.h4),
              GestureDetector(
                onTap: onViewEarnings,
                child: const Text('View All', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Net amount — big number
          Text(
            '\u20B9${net.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            'Net payout from $bookingCount bookings',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          // Breakdown
          Row(
            children: [
              Expanded(
                child: _EarningDetail(
                  label: 'Revenue',
                  value: '\u20B9${revenue.toStringAsFixed(0)}',
                  color: AppColors.textPrimary,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _EarningDetail(
                  label: 'Commission',
                  value: '-\u20B9${commission.toStringAsFixed(0)}',
                  color: AppColors.error,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _EarningDetail(
                  label: 'Net',
                  value: '\u20B9${net.toStringAsFixed(0)}',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (nextPayoutDate != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'Next payout: $nextPayoutDate',
                    style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EarningDetail extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EarningDetail({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
