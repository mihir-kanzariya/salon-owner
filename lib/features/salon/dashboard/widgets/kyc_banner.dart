import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class KycBanner extends StatelessWidget {
  final String kycStatus;
  final String salonId;

  const KycBanner({super.key, required this.kycStatus, required this.salonId});

  @override
  Widget build(BuildContext context) {
    if (kycStatus == 'verified') return const SizedBox.shrink();

    final isNotStarted = kycStatus == 'not_started';
    final isPending = kycStatus == 'pending';
    final isFailed = kycStatus == 'failed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFailed
              ? [AppColors.error, AppColors.error.withValues(alpha: 0.8)]
              : isPending
                  ? [AppColors.accent, AppColors.accentDark]
                  : [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFailed ? Icons.error_outline : isPending ? Icons.hourglass_top : Icons.account_balance_wallet,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFailed
                      ? 'KYC Verification Failed'
                      : isPending
                          ? 'KYC Under Review'
                          : 'Complete Payment Setup',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  isFailed
                      ? 'Please update your documents to receive payouts'
                      : isPending
                          ? 'Your documents are being verified (1-2 days)'
                          : 'Set up bank details to start receiving online payments',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
          if (isNotStarted || isFailed)
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/salon/payment-setup', arguments: salonId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFailed ? 'Update' : 'Setup',
                  style: TextStyle(
                    color: isFailed ? AppColors.error : AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
