import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../services/api_service.dart';

class IncentiveScreen extends StatefulWidget {
  final String salonId;
  const IncentiveScreen({super.key, required this.salonId});

  @override
  State<IncentiveScreen> createState() => _IncentiveScreenState();
}

class _IncentiveScreenState extends State<IncentiveScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _loadIncentiveData();
  }

  Future<void> _loadIncentiveData() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final res = await _api.get('/payments/salon/${widget.salonId}/incentive-progress');
      _data = res['data'] ?? {};
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() { _isLoading = false; _error = 'Could not load incentive data. Pull down to retry.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Monthly Incentive')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(_error!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadIncentiveData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _loadIncentiveData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressCard(),
                    const SizedBox(height: 20),
                    _buildHowItWorks(),
                    const SizedBox(height: 20),
                    _buildPastIncentives(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProgressCard() {
    final current = _data['current_month_bookings'] ?? 0;
    final threshold = _data['threshold'] ?? 150;
    final bonus = (_data['bonus_amount'] ?? 10000).toDouble();
    final eligible = _data['eligible'] ?? false;
    final daysLeft = _data['days_remaining'] ?? 0;
    final progress = (current / threshold).clamp(0.0, 1.0);
    final remaining = threshold - current;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: eligible
              ? [AppColors.success, const Color(0xFF1A8F5C)]
              : [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            eligible ? Icons.emoji_events : Icons.trending_up,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            eligible ? 'Congratulations!' : 'Keep Going!',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            eligible
                ? 'You\'ve earned \u20B9${bonus.toStringAsFixed(0)} bonus this month!'
                : '$remaining more bookings to earn \u20B9${bonus.toStringAsFixed(0)}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 14,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current / $threshold bookings',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                '$daysLeft days left',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How It Works', style: AppTextStyles.h4),
          const SizedBox(height: 16),
          _StepItem(number: '1', text: 'Complete ${_data['threshold'] ?? 150} bookings in a calendar month'),
          _StepItem(number: '2', text: 'Earn \u20B9${(_data['bonus_amount'] ?? 10000).toString()} bonus'),
          const _StepItem(number: '3', text: 'Bonus paid at the start of next month'),
          const _StepItem(number: '4', text: 'Only completed bookings count (cancelled excluded)'),
        ],
      ),
    );
  }

  Widget _buildPastIncentives() {
    final past = List<Map<String, dynamic>>.from((_data['past_incentives'] as List?) ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Past Incentives', style: AppTextStyles.h4),
        const SizedBox(height: 12),
        if (past.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.history, size: 40, color: AppColors.textMuted),
                SizedBox(height: 8),
                Text('No past incentives yet', style: AppTextStyles.bodyMedium),
              ],
            ),
          )
        else
          ...past.map((incentive) {
            final amount = double.tryParse(incentive['amount']?.toString() ?? '0') ?? 0;
            final status = incentive['status'] ?? 'pending';
            final desc = incentive['description'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: status == 'processed' ? AppColors.successLight : AppColors.accentLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      status == 'processed' ? Icons.check_circle : Icons.hourglass_top,
                      color: status == 'processed' ? AppColors.success : AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\u20B9${amount.toStringAsFixed(0)}', style: AppTextStyles.labelLarge),
                        Text(desc, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'processed' ? AppColors.successLight : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status == 'processed' ? 'Paid' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: status == 'processed' ? AppColors.success : AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String text;
  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(number, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
