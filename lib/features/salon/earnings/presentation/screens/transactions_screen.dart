import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../services/api_service.dart';

class TransactionsScreen extends StatefulWidget {
  final String salonId;

  const TransactionsScreen({super.key, required this.salonId});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  // Earnings tab state
  bool _isLoadingEarnings = true;
  List<dynamic> _earnings = [];

  // Withdrawals tab state
  bool _isLoadingWithdrawals = true;
  List<dynamic> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEarnings();
    _loadWithdrawals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEarnings() async {
    try {
      setState(() => _isLoadingEarnings = true);

      final response = await _api.get(
        '/payments/salon/${widget.salonId}/earnings',
      );
      final data = response['data'] ?? {};
      _earnings = data['transactions'] ??
          data['recent_transactions'] ??
          data['earnings'] ??
          [];

      setState(() => _isLoadingEarnings = false);
    } catch (_) {
      setState(() => _isLoadingEarnings = false);
    }
  }

  Future<void> _loadWithdrawals() async {
    try {
      setState(() => _isLoadingWithdrawals = true);

      final response = await _api.get(
        '/payments/salon/${widget.salonId}/withdrawals',
      );
      final data = response['data'];
      if (data is List) {
        _withdrawals = data;
      } else if (data is Map) {
        _withdrawals = data['withdrawals'] ?? data['items'] ?? [];
      } else {
        _withdrawals = [];
      }

      setState(() => _isLoadingWithdrawals = false);
    } catch (_) {
      setState(() => _isLoadingWithdrawals = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.labelLarge,
          unselectedLabelStyle: AppTextStyles.labelMedium,
          tabs: const [
            Tab(text: 'Earnings'),
            Tab(text: 'Withdrawals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEarningsTab(),
          _buildWithdrawalsTab(),
        ],
      ),
    );
  }

  // --------------- Earnings Tab ---------------

  Widget _buildEarningsTab() {
    if (_isLoadingEarnings) {
      return const SkeletonList(child: TransactionItemSkeleton(), count: 5);
    }

    if (_earnings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadEarnings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const EmptyStateWidget(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No Earnings Yet',
              subtitle:
                  'Your earnings from completed bookings will appear here.',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEarnings,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _earnings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final earning = _earnings[index] as Map<String, dynamic>;
          return _buildEarningTile(earning);
        },
      ),
    );
  }

  Widget _buildEarningTile(Map<String, dynamic> earning) {
    final bookingNumber = earning['booking_number'] ??
        earning['bookingNumber'] ??
        earning['booking_id'] ??
        '';
    final date = earning['date'] ??
        earning['created_at'] ??
        earning['createdAt'] ??
        '';
    final totalAmount = earning['total_amount'] ??
        earning['totalAmount'] ??
        earning['amount'] ??
        0;
    final commission = earning['commission'] ??
        earning['commission_amount'] ??
        earning['commissionAmount'] ??
        0;
    final netAmount = earning['net_amount'] ??
        earning['netAmount'] ??
        (totalAmount is num && commission is num
            ? totalAmount - commission
            : 0);

    // H.3: Determine payment method
    final paymentMethod = earning['payment_method'] ??
        earning['paymentMethod'] ?? '';
    final razorpayOrderId = earning['razorpay_order_id'] ??
        earning['razorpayOrderId'] ?? '';
    final isCash = paymentMethod.toString().toLowerCase() == 'cash' ||
        razorpayOrderId.toString().startsWith('pay_at_salon');
    final methodLabel = isCash ? 'Cash' : (paymentMethod.toString().isNotEmpty || razorpayOrderId.toString().isNotEmpty ? 'Online' : '');

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          // Header row: booking number + date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCash ? AppColors.accentLight : AppColors.successLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCash ? Icons.money : Icons.credit_card,
                        color: isCash ? AppColors.accent : AppColors.success,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bookingNumber.toString().isNotEmpty
                                ? 'Booking #$bookingNumber'
                                : 'Booking Payment',
                            style: AppTextStyles.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatDate(date.toString()),
                                style: AppTextStyles.caption,
                              ),
                              if (methodLabel.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (isCash ? AppColors.accent : AppColors.success).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    methodLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isCash ? AppColors.accent : AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+\u20B9${_formatAmount(netAmount)}',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.success,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Amount breakdown
          Row(
            children: [
              Expanded(
                child: _buildAmountColumn(
                  'Total Amount',
                  '\u20B9${_formatAmount(totalAmount)}',
                  AppColors.textPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.border,
              ),
              Expanded(
                child: _buildAmountColumn(
                  'Commission',
                  '-\u20B9${_formatAmount(commission)}',
                  AppColors.error,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.border,
              ),
              Expanded(
                child: _buildAmountColumn(
                  'Net Amount',
                  '\u20B9${_formatAmount(netAmount)}',
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontSize: 11),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.labelLarge.copyWith(
            color: valueColor,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // --------------- Withdrawals Tab ---------------

  Widget _buildWithdrawalsTab() {
    if (_isLoadingWithdrawals) {
      return const SkeletonList(child: TransactionItemSkeleton(), count: 5);
    }

    if (_withdrawals.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadWithdrawals,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const EmptyStateWidget(
              icon: Icons.account_balance_outlined,
              title: 'No Withdrawals Yet',
              subtitle:
                  'Your withdrawal requests will appear here once submitted.',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWithdrawals,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _withdrawals.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final withdrawal = _withdrawals[index] as Map<String, dynamic>;
          return _buildWithdrawalTile(withdrawal);
        },
      ),
    );
  }

  Widget _buildWithdrawalTile(Map<String, dynamic> withdrawal) {
    final amount = withdrawal['amount'] ?? 0;
    final date = withdrawal['date'] ??
        withdrawal['created_at'] ??
        withdrawal['createdAt'] ??
        '';
    final status = (withdrawal['status'] ?? 'pending').toString().toLowerCase();
    final bankDetails = withdrawal['bank_details'] ??
        withdrawal['bankDetails'] as Map<String, dynamic>?;
    final bankName = bankDetails?['bank_name'] ??
        bankDetails?['bankName'] ??
        '';

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Status icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _withdrawalStatusColor(status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _withdrawalStatusIcon(status),
              color: _withdrawalStatusColor(status),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Withdrawal Request',
                        style: AppTextStyles.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\u20B9${_formatAmount(amount)}',
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (bankName.toString().isNotEmpty) ...[
                      Icon(
                        Icons.account_balance,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        bankName.toString(),
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(date.toString()),
                      style: AppTextStyles.caption,
                    ),
                    const Spacer(),
                    _buildWithdrawalStatusBadge(status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalStatusBadge(String status) {
    final color = _withdrawalStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _capitalizeStatus(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _withdrawalStatusColor(String status) {
    switch (status) {
      case 'completed':
      case 'approved':
        return AppColors.success;
      case 'pending':
        return AppColors.accent;
      case 'rejected':
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _withdrawalStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'approved':
        return Icons.thumb_up_outlined;
      case 'pending':
        return Icons.pending_outlined;
      case 'rejected':
      case 'failed':
        return Icons.cancel_outlined;
      default:
        return Icons.account_balance;
    }
  }

  // --------------- Helpers ---------------

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount is num) {
      return amount.toStringAsFixed(
        amount.truncateToDouble() == amount ? 0 : 2,
      );
    }
    return '$amount';
  }

  String _capitalizeStatus(String status) {
    if (status.isEmpty) return status;
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }
}
