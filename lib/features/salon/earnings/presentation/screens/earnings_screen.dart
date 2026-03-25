import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../services/api_service.dart';

class EarningsScreen extends StatefulWidget {
  final String salonId;
  final String? stylistMemberId;

  const EarningsScreen({super.key, required this.salonId, this.stylistMemberId});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _earnings = {};
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    try {
      setState(() => _isLoading = true);

      final queryParams = <String, dynamic>{};
      if (widget.stylistMemberId != null) {
        queryParams['stylist_member_id'] = widget.stylistMemberId!;
      }
      final res = await _api.get(
        '/payments/salon/${widget.salonId}/earnings',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = res['data'] ?? {};
      final summary = data['summary'] as Map<String, dynamic>? ?? {};

      // Map backend response fields to what the UI expects
      _earnings = {
        'total_earnings': _parseNum(summary['total_net']),
        'this_month': _parseNum(summary['total_net']), // same as total for now
        'pending_withdrawal': 0,
        'commission_paid': _parseNum(summary['total_commission']),
      };
      _transactions = (data['earnings'] as List<dynamic>?) ?? [];

      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  num _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/salon/transactions',
                arguments: widget.salonId,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const EarningsSkeleton()
          : RefreshIndicator(
              onRefresh: _loadEarnings,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Cards
                          _buildStatsGrid(),
                          const SizedBox(height: 24),

                          // Earnings Chart Placeholder
                          _buildChartPlaceholder(),
                          const SizedBox(height: 24),

                          // Recent Transactions
                          _buildTransactionsSection(),
                        ],
                      ),
                    ),
                  ),

                  // Withdraw Button (hide for stylists)
                  if (widget.stylistMemberId == null)
                    _buildWithdrawButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    final totalEarnings = _earnings['total_earnings'] ??
        _earnings['totalEarnings'] ??
        0;
    final thisMonth = _earnings['this_month'] ??
        _earnings['thisMonth'] ??
        0;
    final pendingWithdrawal = _earnings['pending_withdrawal'] ??
        _earnings['pendingWithdrawal'] ??
        0;
    final commissionPaid = _earnings['commission_paid'] ??
        _earnings['commissionPaid'] ??
        0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _EarningsCard(
          title: 'Total Earnings',
          amount: _formatCurrency(totalEarnings),
          icon: Icons.account_balance_wallet,
          color: AppColors.primary,
          bgColor: AppColors.primary.withValues(alpha: 0.1),
        ),
        _EarningsCard(
          title: 'This Month',
          amount: _formatCurrency(thisMonth),
          icon: Icons.calendar_month,
          color: AppColors.success,
          bgColor: AppColors.successLight,
        ),
        _EarningsCard(
          title: 'Pending Withdrawal',
          amount: _formatCurrency(pendingWithdrawal),
          icon: Icons.pending_actions,
          color: AppColors.accent,
          bgColor: AppColors.accentLight,
        ),
        _EarningsCard(
          title: 'Commission Paid',
          amount: _formatCurrency(commissionPaid),
          icon: Icons.receipt_long,
          color: AppColors.error,
          bgColor: AppColors.errorLight,
        ),
      ],
    );
  }

  Widget _buildChartPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Earnings Chart',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chart coming soon',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions', style: AppTextStyles.h4),
            if (_transactions.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/salon/transactions',
                    arguments: widget.salonId,
                  );
                },
                child: Text(
                  'View All',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          _buildEmptyTransactions()
        else
          ..._transactions.map((transaction) {
            return _TransactionTile(
              date: transaction['date'] ??
                  transaction['created_at'] ??
                  '',
              amount: transaction['amount'] ?? 0,
              type: transaction['type'] ?? 'booking',
              status: transaction['status'] ?? 'completed',
              description: transaction['description'] ?? '',
            );
          }),
      ],
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'No transactions yet',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Your earnings from bookings will appear here',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: AppButton(
          text: 'Withdraw Funds',
          icon: Icons.account_balance,
          onPressed: () {
            final available = (_earnings['total_earnings'] as num?)?.toDouble() ?? 0.0;
            Navigator.pushNamed(
              context,
              '/salon/withdraw',
              arguments: {
                'salon_id': widget.salonId,
                'available_balance': available,
              },
            );
          },
        ),
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount is num) {
      if (amount >= 100000) {
        return '\u20B9${(amount / 1000).toStringAsFixed(1)}K';
      }
      return '\u20B9${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
    }
    return '\u20B9$amount';
  }
}

class _EarningsCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _EarningsCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: AppTextStyles.h3.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final String date;
  final dynamic amount;
  final String type;
  final String status;
  final String description;

  const _TransactionTile({
    required this.date,
    required this.amount,
    required this.type,
    required this.status,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          // Type icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        description.isNotEmpty
                            ? description
                            : _typeLabel,
                        style: AppTextStyles.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTypeBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_formatDate(date), style: AppTextStyles.caption),
                    const Spacer(),
                    _buildStatusBadge(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Amount
          Text(
            _isDebit
                ? '-\u20B9${_formatAmount(amount)}'
                : '+\u20B9${_formatAmount(amount)}',
            style: AppTextStyles.h4.copyWith(
              color: _isDebit ? AppColors.error : AppColors.success,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isDebit =>
      type == 'commission' || type == 'withdrawal';

  Color get _typeColor {
    switch (type) {
      case 'booking':
        return AppColors.success;
      case 'commission':
        return AppColors.accent;
      case 'withdrawal':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData get _typeIcon {
    switch (type) {
      case 'booking':
        return Icons.calendar_today;
      case 'commission':
        return Icons.percent;
      case 'withdrawal':
        return Icons.account_balance;
      default:
        return Icons.receipt;
    }
  }

  String get _typeLabel {
    switch (type) {
      case 'booking':
        return 'Booking Payment';
      case 'commission':
        return 'Commission';
      case 'withdrawal':
        return 'Withdrawal';
      default:
        return type;
    }
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _typeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _typeLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _typeColor,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color statusColor;
    switch (status) {
      case 'completed':
      case 'success':
        statusColor = AppColors.success;
        break;
      case 'pending':
        statusColor = AppColors.accent;
        break;
      case 'failed':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.textMuted;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _formatStatus(status),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount is num) {
      return amount
          .toStringAsFixed(
              amount.truncateToDouble() == amount ? 0 : 2);
    }
    return '$amount';
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : '')
        .join(' ');
  }
}
