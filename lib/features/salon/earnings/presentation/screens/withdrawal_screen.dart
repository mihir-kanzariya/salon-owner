import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../config/api_config.dart';
import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../services/api_service.dart';

class WithdrawalScreen extends StatefulWidget {
  final String salonId;
  final double availableBalance; // Kept for backward compat, but we fetch fresh

  const WithdrawalScreen({
    super.key,
    required this.salonId,
    required this.availableBalance,
  });

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _savedBank;
  Map<String, dynamic> _wallet = {};

  double get _withdrawableBalance =>
      double.tryParse(_wallet['withdrawable_balance']?.toString() ?? '') ??
      double.tryParse(_wallet['available_balance']?.toString() ?? '') ??
      widget.availableBalance;

  double get _totalBalance =>
      double.tryParse(_wallet['total_balance']?.toString() ?? '') ?? 0;

  double get _heldBalance =>
      double.tryParse(_wallet['held_balance']?.toString() ?? '') ?? 0;

  double get _pendingWithdrawals =>
      double.tryParse(_wallet['pending_withdrawals']?.toString() ?? '') ?? 0;

  double get _minWithdrawal =>
      double.tryParse(_wallet['min_withdrawal']?.toString() ?? '') ?? 500;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadWallet(), _loadBankAccount()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadWallet() async {
    try {
      final res = await _api.get(ApiConfig.walletSummary(widget.salonId));
      if (res['data'] != null) _wallet = res['data'];
    } catch (_) {
      // Fall back to passed balance
    }
  }

  Future<void> _loadBankAccount() async {
    try {
      final res = await _api.get('/salons/${widget.salonId}/bank-account');
      if (res['data'] != null) _savedBank = res['data'];
    } catch (_) {}
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_savedBank == null) {
      SnackbarUtils.showError(context, 'Please set up your bank account first');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _api.post(ApiConfig.walletWithdraw(widget.salonId), body: {
        'amount': double.parse(_amountController.text.trim()),
      });
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Withdrawal request submitted successfully');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) SnackbarUtils.showError(context, e.message);
    } catch (_) {
      setState(() => _isSubmitting = false);
      if (mounted) SnackbarUtils.showError(context, 'Failed to submit withdrawal request');
    }
  }

  String _fmt(double amount) {
    if (amount >= 100000) return '\u20B9${(amount / 1000).toStringAsFixed(1)}K';
    return '\u20B9${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.tr('withdraw_funds'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWalletCard(l),
                            const SizedBox(height: 16),
                            _buildBankCard(l),
                            const SizedBox(height: 16),
                            _buildAmountSection(l),
                            const SizedBox(height: 16),
                            _buildInfoNote(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildSubmitButton(l),
              ],
            ),
    );
  }

  Widget _buildWalletCard(LocaleProvider l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet, color: AppColors.white, size: 20),
            const SizedBox(width: 8),
            Text(l.tr('available_balance'), style: AppTextStyles.labelLarge.copyWith(color: AppColors.white.withValues(alpha: 0.85))),
          ]),
          const SizedBox(height: 8),
          Text(_fmt(_withdrawableBalance), style: AppTextStyles.h1.copyWith(color: AppColors.white, fontSize: 36)),
          const SizedBox(height: 16),
          // Balance breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _balanceRow(l.tr('total_balance'), _fmt(_totalBalance)),
                if (_heldBalance > 0) ...[
                  const SizedBox(height: 6),
                  _balanceRow('${l.tr('held')} (7-day hold)', _fmt(_heldBalance), color: AppColors.warningLight),
                ],
                if (_pendingWithdrawals > 0) ...[
                  const SizedBox(height: 6),
                  _balanceRow(l.tr('pending_withdrawal'), '-${_fmt(_pendingWithdrawals)}', color: AppColors.warningLight),
                ],
                const SizedBox(height: 6),
                const Divider(color: AppColors.white, height: 1),
                const SizedBox(height: 6),
                _balanceRow(l.tr('withdrawable'), _fmt(_withdrawableBalance), isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: color ?? AppColors.white.withValues(alpha: 0.85))),
        Text(value, style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.white,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
        )),
      ],
    );
  }

  Widget _buildBankCard(LocaleProvider l) {
    if (_savedBank == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          const Icon(Icons.account_balance, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(l.tr('no_bank_account'), style: AppTextStyles.h4),
          const SizedBox(height: 8),
          Text(l.tr('setup_bank_subtitle'), style: AppTextStyles.caption, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppButton(
            text: l.tr('setup_bank'),
            onPressed: () async {
              await Navigator.pushNamed(context, '/salon/bank-account', arguments: widget.salonId);
              _loadBankAccount().then((_) { if (mounted) setState(() {}); });
            },
            icon: Icons.add,
          ),
        ]),
      );
    }

    final masked = _maskAccount(_savedBank!['account_number']?.toString());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(l.tr('bank_account'), style: AppTextStyles.h4)),
          GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(context, '/salon/bank-account', arguments: widget.salonId);
              _loadBankAccount().then((_) { if (mounted) setState(() {}); });
            },
            child: Text(l.tr('change_bank'), style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check_circle, color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(masked, style: AppTextStyles.labelLarge),
            Text('${_savedBank!['bank_name'] ?? 'Bank'} | ${_savedBank!['holder_name'] ?? ''}', style: AppTextStyles.caption),
          ]),
        ]),
      ]),
    );
  }

  String _maskAccount(String? num) {
    if (num == null || num.length <= 4) return num ?? '****';
    return '${'*' * (num.length - 4)}${num.substring(num.length - 4)}';
  }

  Widget _buildAmountSection(LocaleProvider l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.tr('withdrawal_amount'), style: AppTextStyles.h4),
        const SizedBox(height: 16),
        AppTextField(
          controller: _amountController,
          hint: 'Enter withdrawal amount',
          prefixIcon: Icons.currency_rupee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Please enter an amount';
            final amount = double.tryParse(value.trim());
            if (amount == null || amount <= 0) return 'Please enter a valid amount';
            if (amount < _minWithdrawal) return 'Minimum withdrawal is \u20B9${_minWithdrawal.toStringAsFixed(0)}';
            if (amount > _withdrawableBalance) return 'Amount exceeds withdrawable balance (\u20B9${_withdrawableBalance.toStringAsFixed(0)})';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text('Min: \u20B9${_minWithdrawal.toStringAsFixed(0)} | Max: \u20B9${_withdrawableBalance.toStringAsFixed(0)}', style: AppTextStyles.caption),
      ]),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: AppColors.accentDark, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('Withdrawal requests are typically processed within 2-3 business days. Funds are held for 7 days after earning before becoming withdrawable.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentDark, height: 1.4))),
      ]),
    );
  }

  Widget _buildSubmitButton(LocaleProvider l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))]),
      child: SafeArea(
        top: false,
        child: AppButton(
          text: l.tr('submit_withdrawal'),
          onPressed: (_isSubmitting || _savedBank == null || _withdrawableBalance < _minWithdrawal) ? null : _submitWithdrawal,
          isLoading: _isSubmitting,
          icon: _isSubmitting ? null : Icons.send,
        ),
      ),
    );
  }
}
