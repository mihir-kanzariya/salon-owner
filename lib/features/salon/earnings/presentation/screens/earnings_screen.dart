import '../../../../../config/api_config.dart';
import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/widgets/language_toggle.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
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
  bool _hasError = false;
  Map<String, dynamic> _earnings = {};
  Map<String, dynamic> _wallet = {};
  List<dynamic> _transactions = [];
  List<Map<String, dynamic>> _dailyEarnings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      // Load wallet first, then earnings (earnings uses wallet data)
      await _loadWallet();
      await _loadEarnings();
      _computeDailyEarnings();
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _computeDailyEarnings() {
    // Build last 7 days from transactions
    final now = DateTime.now();
    final Map<String, double> dayMap = {};
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      dayMap[DateFormat('yyyy-MM-dd').format(d)] = 0;
    }
    for (final t in _transactions) {
      final dateStr = t['createdAt'] ?? t['created_at'] ?? t['date'] ?? '';
      if (dateStr is String && dateStr.isNotEmpty) {
        try {
          final key = DateFormat('yyyy-MM-dd').format(DateTime.parse(dateStr));
          if (dayMap.containsKey(key)) {
            final amount = (t['net_amount'] ?? t['amount'] ?? 0);
            dayMap[key] = dayMap[key]! + (amount is num ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0);
          }
        } catch (_) {}
      }
    }
    _dailyEarnings = dayMap.entries.map((e) => {'date': e.key, 'amount': e.value}).toList();
  }

  Future<void> _loadWallet() async {
    try {
      final res = await _api.get(ApiConfig.walletSummary(widget.salonId));
      if (res['data'] != null) _wallet = res['data'];
    } catch (_) {}
  }

  Future<void> _loadEarnings() async {
    try {
      final queryParams = <String, dynamic>{};
      if (widget.stylistMemberId != null) {
        queryParams['stylist_member_id'] = widget.stylistMemberId!;
      }
      final res = await _api.get(
        '/payments/salon/${widget.salonId}/earnings',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      // API returns data flat: { total_earned, total_commission, total_net, total_bookings, earnings: [] }
      // NOT nested under data.summary
      final data = res['data'] ?? {};

      _earnings = {
        'total_earnings': _parseNum(data['total_net']),
        'available': _parseNum(_wallet['available_balance']),
        'held': _parseNum(_wallet['held_balance']),
        'pending_withdrawal': _parseNum(_wallet['pending_withdrawals']),
        'commission_paid': _parseNum(data['total_commission']),
        'withdrawable': _parseNum(_wallet['withdrawable_balance']),
        'total_bookings': _parseNum(data['total_bookings']),
      };
      _transactions = (data['earnings'] as List<dynamic>?) ?? [];
    } catch (_) {}
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
        title: Text(context.watch<LocaleProvider>().tr('earnings')),
        actions: [
          const LanguageToggle(),
          const SizedBox(width: 4),
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
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Failed to load earnings', style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                )
          : RefreshIndicator(
              onRefresh: _loadData,
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
    final l = context.watch<LocaleProvider>();
    final withdrawable = _earnings['withdrawable'] ?? 0;
    final totalEarnings = _earnings['total_earnings'] ?? 0;
    final pendingWithdrawal = _earnings['pending_withdrawal'] ?? 0;
    final commissionPaid = _earnings['commission_paid'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _EarningsCard(
          title: l.tr('withdrawable'),
          amount: _formatCurrency(withdrawable),
          icon: Icons.account_balance_wallet,
          color: AppColors.primary,
          bgColor: AppColors.primary.withValues(alpha: 0.1),
        ),
        _EarningsCard(
          title: l.tr('net_earnings'),
          amount: _formatCurrency(totalEarnings),
          icon: Icons.trending_up,
          color: AppColors.success,
          bgColor: AppColors.successLight,
        ),
        _EarningsCard(
          title: l.tr('pending_withdrawal'),
          amount: _formatCurrency(pendingWithdrawal),
          icon: Icons.pending_actions,
          color: AppColors.accent,
          bgColor: AppColors.accentLight,
        ),
        _EarningsCard(
          title: l.tr('commission'),
          amount: _formatCurrency(commissionPaid),
          icon: Icons.receipt_long,
          color: AppColors.error,
          bgColor: AppColors.errorLight,
        ),
      ],
    );
  }

  Widget _buildChartPlaceholder() {
    final l = context.watch<LocaleProvider>();
    if (_dailyEarnings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(l.tr('earnings_chart'), style: AppTextStyles.h4),
            const SizedBox(height: 24),
            Icon(Icons.bar_chart, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(l.tr('no_data'), style: AppTextStyles.caption),
          ],
        ),
      );
    }

    final maxAmount = _dailyEarnings.fold<double>(
      0, (prev, e) => (e['amount'] as double) > prev ? (e['amount'] as double) : prev,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.tr('earnings_chart'), style: AppTextStyles.h4),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _dailyEarnings.map((day) {
                final amount = day['amount'] as double;
                final ratio = maxAmount > 0 ? amount / maxAmount : 0.0;
                final dateStr = day['date'] as String;
                String label;
                try {
                  label = DateFormat('EEE').format(DateTime.parse(dateStr));
                } catch (_) {
                  label = dateStr.substring(dateStr.length - 2);
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (amount > 0)
                          Text(
                            '\u20B9${amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Container(
                          height: (ratio * 100).clamp(4.0, 100.0),
                          decoration: BoxDecoration(
                            color: amount > 0 ? AppColors.primary : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
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
            Text(context.watch<LocaleProvider>().tr('recent_transactions'), style: AppTextStyles.h4),
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
                  context.watch<LocaleProvider>().tr('view_all'),
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
              date: transaction['createdAt'] ??
                  transaction['created_at'] ??
                  transaction['date'] ??
                  '',
              amount: transaction['net_amount'] ??
                  transaction['amount'] ?? 0,
              type: transaction['type'] ?? 'booking',
              status: transaction['status'] ?? 'pending',
              description: transaction['description'] ??
                  'Booking #${transaction['booking']?['booking_number'] ?? ''}',
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
          Text(
            context.watch<LocaleProvider>().tr('no_transactions'),
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.watch<LocaleProvider>().tr('earnings_appear_here'),
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
          text: context.watch<LocaleProvider>().tr('withdraw_funds'),
          icon: Icons.account_balance,
          onPressed: () {
            final withdrawable = (_earnings['withdrawable'] as num?)?.toDouble() ?? 0.0;
            Navigator.pushNamed(
              context,
              '/salon/withdraw',
              arguments: {
                'salon_id': widget.salonId,
                'available_balance': withdrawable,
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
