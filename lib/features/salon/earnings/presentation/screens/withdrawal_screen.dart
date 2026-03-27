import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../services/api_service.dart';

class WithdrawalScreen extends StatefulWidget {
  final String salonId;
  final double availableBalance;

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

  bool _isSubmitting = false;
  bool _isLoadingBank = true;
  Map<String, dynamic>? _savedBank;

  @override
  void initState() {
    super.initState();
    _loadBankAccount();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBankAccount() async {
    try {
      final res = await _api.get('/salons/${widget.salonId}/bank-account');
      if (res['data'] != null) {
        setState(() { _savedBank = res['data']; _isLoadingBank = false; });
      } else {
        setState(() => _isLoadingBank = false);
      }
    } catch (_) {
      setState(() => _isLoadingBank = false);
    }
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_savedBank == null) {
      SnackbarUtils.showError(context, 'Please set up your bank account first');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _api.post('/payments/salon/${widget.salonId}/withdraw', body: {
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

  String _formatCurrency(double amount) {
    if (amount >= 100000) return '\u20B9${(amount / 1000).toStringAsFixed(1)}K';
    return '\u20B9${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(context.watch<LocaleProvider>().tr('withdraw_funds'))),
      body: _isLoadingBank
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBalanceCard(),
                          const SizedBox(height: 24),
                          _buildBankCard(),
                          const SizedBox(height: 24),
                          _buildAmountSection(),
                          const SizedBox(height: 16),
                          _buildInfoNote(),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildSubmitButton(),
              ],
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            Text(context.watch<LocaleProvider>().tr('available_balance'), style: AppTextStyles.labelLarge.copyWith(color: AppColors.white.withValues(alpha: 0.85))),
          ]),
          const SizedBox(height: 12),
          Text(_formatCurrency(widget.availableBalance), style: AppTextStyles.h1.copyWith(color: AppColors.white, fontSize: 36)),
        ],
      ),
    );
  }

  Widget _buildBankCard() {
    if (_savedBank == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          const Icon(Icons.account_balance, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(context.watch<LocaleProvider>().tr('no_bank_account'), style: AppTextStyles.h4),
          const SizedBox(height: 8),
          Text(context.watch<LocaleProvider>().tr('setup_bank_subtitle'), style: AppTextStyles.caption, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppButton(
            text: context.watch<LocaleProvider>().tr('setup_bank'),
            onPressed: () async {
              await Navigator.pushNamed(context, '/salon/bank-account', arguments: widget.salonId);
              _loadBankAccount();
            },
            icon: Icons.add,
          ),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(context.watch<LocaleProvider>().tr('bank_account'), style: AppTextStyles.h4)),
          GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(context, '/salon/bank-account', arguments: widget.salonId);
              _loadBankAccount();
            },
            child: Text(context.watch<LocaleProvider>().tr('change_bank'), style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
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
            Text(_savedBank!['account_number'] ?? '****', style: AppTextStyles.labelLarge),
            Text('${_savedBank!['bank_name'] ?? 'Bank'} | ${_savedBank!['holder_name'] ?? ''}', style: AppTextStyles.caption),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildAmountSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.watch<LocaleProvider>().tr('withdrawal_amount'), style: AppTextStyles.h4),
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
            if (amount < 500) return 'Minimum withdrawal is \u20B9500';
            if (amount > widget.availableBalance) return 'Amount exceeds available balance';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text('Min: \u20B9500 | Max: \u20B9${widget.availableBalance.toStringAsFixed(0)}', style: AppTextStyles.caption),
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
        Expanded(child: Text('Withdrawal requests are typically processed within 2-3 business days.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentDark, height: 1.4))),
      ]),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))]),
      child: SafeArea(
        top: false,
        child: AppButton(
          text: context.watch<LocaleProvider>().tr('submit_withdrawal'),
          onPressed: (_isSubmitting || _savedBank == null) ? null : _submitWithdrawal,
          isLoading: _isSubmitting,
          icon: _isSubmitting ? null : Icons.send,
        ),
      ),
    );
  }
}
