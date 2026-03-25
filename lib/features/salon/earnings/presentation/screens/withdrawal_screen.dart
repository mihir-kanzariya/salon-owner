import 'package:flutter/material.dart';
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
  final _holderNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _holderNameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _api.post(
        '/payments/salon/${widget.salonId}/withdraw',
        body: {
          'amount': double.parse(_amountController.text.trim()),
          'bank_details': {
            'holder_name': _holderNameController.text.trim(),
            'bank_name': _bankNameController.text.trim(),
            'account_number': _accountNumberController.text.trim(),
            'ifsc': _ifscController.text.trim(),
          },
        },
      );

      if (!mounted) return;
      SnackbarUtils.showSuccess(
        context,
        'Withdrawal request submitted successfully',
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) SnackbarUtils.showError(context, e.message);
    } catch (_) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Failed to submit withdrawal request',
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '\u20B9${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u20B9${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Available balance card
                    _buildBalanceCard(),
                    const SizedBox(height: 24),

                    // Amount section
                    _buildAmountSection(),
                    const SizedBox(height: 24),

                    // Bank details section
                    _buildBankDetailsSection(),
                    const SizedBox(height: 16),

                    // Info note
                    _buildInfoNote(),
                  ],
                ),
              ),
            ),
          ),

          // Submit button
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
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: AppColors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Available Balance',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(widget.availableBalance),
            style: AppTextStyles.h1.copyWith(
              color: AppColors.white,
              fontSize: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
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
          const Text('Withdrawal Amount', style: AppTextStyles.h4),
          const SizedBox(height: 16),
          AppTextField(
            controller: _amountController,
            hint: 'Enter withdrawal amount',
            prefixIcon: Icons.currency_rupee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an amount';
              }
              final amount = double.tryParse(value.trim());
              if (amount == null || amount <= 0) {
                return 'Please enter a valid amount';
              }
              if (amount > widget.availableBalance) {
                return 'Amount exceeds available balance (\u20B9${widget.availableBalance.toStringAsFixed(0)})';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Maximum: \u20B9${widget.availableBalance.toStringAsFixed(0)}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              const Icon(
                Icons.account_balance,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text('Bank Details', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 20),

          // Account holder name
          AppTextField(
            controller: _holderNameController,
            label: 'Account Holder Name',
            hint: 'Enter account holder name',
            prefixIcon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter account holder name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Bank name
          AppTextField(
            controller: _bankNameController,
            label: 'Bank Name',
            hint: 'Enter bank name',
            prefixIcon: Icons.business,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter bank name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Account number
          AppTextField(
            controller: _accountNumberController,
            label: 'Account Number',
            hint: 'Enter account number',
            prefixIcon: Icons.numbers,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter account number';
              }
              if (value.trim().length < 8) {
                return 'Please enter a valid account number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // IFSC code
          AppTextField(
            controller: _ifscController,
            label: 'IFSC Code',
            hint: 'Enter IFSC code',
            prefixIcon: Icons.code,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter IFSC code';
              }
              if (value.trim().length != 11) {
                return 'IFSC code must be 11 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.accentDark,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Withdrawal requests are typically processed within 2-3 business days. You will be notified once the transfer is complete.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.accentDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
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
        top: false,
        child: AppButton(
          text: 'Submit Withdrawal Request',
          onPressed: _isSubmitting ? null : _submitWithdrawal,
          isLoading: _isSubmitting,
          icon: _isSubmitting ? null : Icons.send,
        ),
      ),
    );
  }
}
