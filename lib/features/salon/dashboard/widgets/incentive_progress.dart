import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class IncentiveProgress extends StatelessWidget {
  final int currentBookings;
  final int threshold;
  final int daysRemaining;
  final double bonusAmount;

  const IncentiveProgress({
    super.key,
    required this.currentBookings,
    this.threshold = 150,
    required this.daysRemaining,
    this.bonusAmount = 10000,
  });

  @override
  Widget build(BuildContext context) {
    final progress = threshold > 0 ? (currentBookings / threshold).clamp(0.0, 1.0) : 0.0;
    final remaining = (threshold - currentBookings).clamp(0, threshold);
    final isEligible = currentBookings >= threshold && threshold > 0;

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
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isEligible ? AppColors.successLight : AppColors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEligible ? Icons.emoji_events : Icons.trending_up,
                  color: isEligible ? AppColors.success : AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monthly Incentive', style: AppTextStyles.h4),
                    Text(
                      isEligible
                          ? 'You\'ve earned \u20B9${bonusAmount.toStringAsFixed(0)} bonus!'
                          : '$remaining more bookings to earn \u20B9${bonusAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isEligible ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.softSurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                isEligible ? AppColors.success : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currentBookings / $threshold bookings',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              Text(
                '$daysRemaining days left',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
