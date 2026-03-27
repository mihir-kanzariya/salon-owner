import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../services/api_service.dart';

class BankAccountSetupScreen extends StatefulWidget {
  final String salonId;
  const BankAccountSetupScreen({super.key, required this.salonId});

  @override
  State<BankAccountSetupScreen> createState() => _BankAccountSetupScreenState();
}

class _BankAccountSetupScreenState extends State<BankAccountSetupScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _holderController = TextEditingController();
  final _accountController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscController = TextEditingController();

  String? _bankName;
  bool _isLookingUp = false;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _hasExisting = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
    _ifscController.addListener(_onIfscChanged);
  }

  @override
  void dispose() {
    _holderController.dispose();
    _accountController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final res = await _api.get('/salons/${widget.salonId}/bank-account');
      if (res['data'] != null) {
        final d = res['data'];
        _holderController.text = d['holder_name'] ?? '';
        _ifscController.text = d['ifsc'] ?? '';
        _bankName = d['bank_name'];
        _hasExisting = true;
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _onIfscChanged() {
    final code = _ifscController.text.trim().toUpperCase();
    if (code.length == 11 && RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(code)) {
      _lookupIfsc(code);
    } else {
      setState(() => _bankName = null);
    }
  }

  Future<void> _lookupIfsc(String code) async {
    setState(() => _isLookingUp = true);
    try {
      final res = await _api.get('/utils/ifsc/$code');
      setState(() { _bankName = res['data']?['bank'] ?? 'Unknown Bank'; _isLookingUp = false; });
    } catch (_) {
      setState(() { _bankName = null; _isLookingUp = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountController.text != _confirmAccountController.text) {
      SnackbarUtils.showError(context, 'Account numbers do not match');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _api.put('/salons/${widget.salonId}/bank-account', body: {
        'holder_name': _holderController.text.trim(),
        'account_number': _accountController.text.trim(),
        'ifsc': _ifscController.text.trim().toUpperCase(),
        'bank_name': _bankName ?? '',
      });
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Bank account saved successfully');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _isSaving = false);
      if (mounted) SnackbarUtils.showError(context, e.message);
    } catch (_) {
      setState(() => _isSaving = false);
      if (mounted) SnackbarUtils.showError(context, 'Failed to save bank account');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.tr('bank_account'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                        ),
                        child: Column(children: [
                          Icon(Icons.account_balance, size: 40, color: AppColors.primary),
                          const SizedBox(height: 8),
                          Text(_hasExisting ? 'Update Bank Account' : 'Set Up Bank Account',
                            style: AppTextStyles.h3, textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text('Your earnings will be transferred to this account',
                            style: AppTextStyles.caption, textAlign: TextAlign.center),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // Account Holder Name
                      AppTextField(
                        controller: _holderController,
                        label: l.tr('beneficiary_name'),
                        hint: 'Enter account holder name',
                        prefixIcon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // IFSC Code
                      AppTextField(
                        controller: _ifscController,
                        label: l.tr('ifsc_code'),
                        hint: 'e.g. HDFC0001234',
                        prefixIcon: Icons.code,
                        maxLength: 11,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.trim().toUpperCase())) return 'Invalid IFSC format';
                          return null;
                        },
                      ),

                      // Bank name (auto-fetched)
                      if (_isLookingUp)
                        const Padding(padding: EdgeInsets.all(8), child: Row(children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Looking up bank...', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ]))
                      else if (_bankName != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Text(_bankName!, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
                          ]),
                        ),

                      const SizedBox(height: 8),

                      // Account Number
                      AppTextField(
                        controller: _accountController,
                        label: l.tr('account_number'),
                        hint: 'Enter account number',
                        prefixIcon: Icons.numbers,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().length < 8) return 'At least 8 digits';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Account Number
                      AppTextField(
                        controller: _confirmAccountController,
                        label: 'Confirm Account Number',
                        hint: 'Re-enter account number',
                        prefixIcon: Icons.numbers,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim() != _accountController.text.trim()) return 'Account numbers do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Security note
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.softSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.security, color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            'Your bank details are encrypted and stored securely. They will only be used for processing your withdrawal requests.',
                            style: AppTextStyles.caption.copyWith(height: 1.4),
                          )),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),

              // Save button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
                ),
                child: SafeArea(
                  top: false,
                  child: AppButton(
                    text: _hasExisting ? 'Update Bank Account' : l.tr('save'),
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                    icon: _isSaving ? null : Icons.check,
                  ),
                ),
              ),
            ]),
    );
  }
}
