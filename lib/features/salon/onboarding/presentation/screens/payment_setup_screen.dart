import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../../../config/api_config.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/utils/storage_service.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';

/// Production-ready payment setup with 3 states:
/// 1. Setup form (new account)
/// 2. View details (existing account - verifiable)
/// 3. Edit mode (update bank details or contact info)
class PaymentSetupScreen extends StatefulWidget {
  final String salonId;
  const PaymentSetupScreen({super.key, required this.salonId});

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  // States: 'setup', 'view', 'edit_bank', 'edit_contact'
  String _screenState = 'setup';

  // Existing account data
  Map<String, dynamic>? _accountData;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final _businessNameCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  String _businessType = 'individual';
  final _panCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _beneficiaryNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingAccount();
  }

  Future<String?> _getToken() async => StorageService().getAccessToken();

  Future<void> _loadExistingAccount() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.linkedAccount(widget.salonId)}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (data != null) {
          _accountData = data;
          _screenState = 'view';
        } else {
          _screenState = 'setup';
        }
      } else {
        _screenState = 'setup';
      }
    } catch (e) {
      _screenState = 'setup';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSubmitting = true; _error = null; });
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.linkedAccount(widget.salonId)}'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'legal_business_name': _businessNameCtrl.text.trim(),
          'business_type': _businessType,
          'contact_name': _contactNameCtrl.text.trim(),
          'contact_email': _contactEmailCtrl.text.trim(),
          'contact_phone': _contactPhoneCtrl.text.trim(),
          'pan': _panCtrl.text.trim().toUpperCase(),
          if (_gstCtrl.text.trim().isNotEmpty) 'gst': _gstCtrl.text.trim().toUpperCase(),
          'bank_account_number': _accountNumberCtrl.text.trim(),
          'bank_ifsc': _ifscCtrl.text.trim().toUpperCase(),
          'bank_beneficiary_name': _beneficiaryNameCtrl.text.trim(),
        }),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        _showSnackBar('Payment setup submitted successfully!', isSuccess: true);
        await _loadExistingAccount();
      } else {
        setState(() => _error = body['message'] ?? 'Failed to submit');
      }
    } catch (e) {
      setState(() => _error = 'Network error. Please try again.');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _updateDetails(Map<String, dynamic> updateData) async {
    setState(() { _isSubmitting = true; _error = null; });
    try {
      final token = await _getToken();
      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.linkedAccount(widget.salonId)}'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _showSnackBar('Details updated successfully!', isSuccess: true);
        await _loadExistingAccount();
      } else {
        setState(() => _error = body['message'] ?? 'Failed to update');
      }
    } catch (e) {
      setState(() => _error = 'Network error. Please try again.');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _refreshKycStatus() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.refreshKycStatus(widget.salonId)}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        _showSnackBar('KYC Status: ${data['kyc_status']}');
        await _loadExistingAccount();
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnackBar(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? AppColors.success : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.tr('payment_setup')),
        actions: [
          if (_screenState == 'view')
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshKycStatus, tooltip: 'Refresh KYC Status'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _screenState == 'view'
              ? _buildViewState()
              : (_screenState == 'edit_bank' || _screenState == 'edit_contact')
                  ? _buildEditState()
                  : _buildSetupForm(),
    );
  }

  // ──────────────── VIEW STATE (Existing Account) ────────────────

  Widget _buildViewState() {
    final l = context.watch<LocaleProvider>();
    final d = _accountData!;
    final kycStatus = d['kyc_status'] ?? 'pending';
    final accountStatus = d['status'] ?? 'created';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KYC Status Banner
        _buildStatusBanner(kycStatus, accountStatus),
        const SizedBox(height: 16),

        // Business Details Card
        _buildInfoCard(
          title: l.tr('business_details'),
          icon: Icons.business,
          items: [
            _InfoItem(label: 'Business Name', value: d['legal_business_name'] ?? '-'),
            _InfoItem(label: 'Business Type', value: (d['business_type'] ?? '-').toString().replaceAll('_', ' ')),
          ],
        ),
        const SizedBox(height: 12),

        // Contact Details Card (Editable)
        _buildInfoCard(
          title: 'Contact Details',
          icon: Icons.person,
          onEdit: () {
            _contactEmailCtrl.text = d['contact_email'] ?? '';
            _contactPhoneCtrl.text = d['contact_phone'] ?? '';
            setState(() => _screenState = 'edit_contact');
          },
          items: [
            _InfoItem(label: 'Contact Name', value: d['contact_name'] ?? '-'),
            _InfoItem(label: 'Email', value: d['contact_email'] ?? '-'),
            _InfoItem(label: 'Phone', value: d['contact_phone'] ?? '-'),
          ],
        ),
        const SizedBox(height: 12),

        // Bank Details Card (Editable)
        _buildInfoCard(
          title: l.tr('bank_details'),
          icon: Icons.account_balance,
          onEdit: () {
            _accountNumberCtrl.text = '';
            _ifscCtrl.text = d['bank_ifsc'] ?? '';
            _beneficiaryNameCtrl.text = d['bank_beneficiary_name'] ?? '';
            setState(() => _screenState = 'edit_bank');
          },
          items: [
            _InfoItem(label: 'Beneficiary', value: d['bank_beneficiary_name'] ?? '-'),
            _InfoItem(label: 'IFSC', value: d['bank_ifsc'] ?? '-'),
            _InfoItem(label: 'Account', value: _maskAccountNumber(d['bank_account_number'])),
          ],
        ),
        const SizedBox(height: 24),

        // Refresh Status Button
        OutlinedButton.icon(
          onPressed: _refreshKycStatus,
          icon: const Icon(Icons.refresh),
          label: Text(l.tr('refresh_status')),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatusBanner(String kycStatus, String accountStatus) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    switch (kycStatus) {
      case 'verified':
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.verified;
        title = 'KYC Verified';
        subtitle = 'Your account is active and ready to receive payments.';
        break;
      case 'failed':
        bgColor = AppColors.errorLight;
        textColor = AppColors.error;
        icon = Icons.error_outline;
        title = 'KYC Failed';
        subtitle = 'Please update your details and try again.';
        break;
      default:
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.hourglass_empty;
        title = 'KYC Under Review';
        subtitle = 'Your details are being verified. This usually takes 1-2 business days.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: textColor.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700))),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary, visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const Divider(height: 20),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                Text(item.value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _maskAccountNumber(String? number) {
    if (number == null || number.isEmpty) return '-';
    if (number.length <= 4) return number;
    return '${'*' * (number.length - 4)}${number.substring(number.length - 4)}';
  }

  // ──────────────── EDIT STATE ────────────────

  Widget _buildEditState() {
    final isBank = _screenState == 'edit_bank';
    final l = context.watch<LocaleProvider>();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            isBank ? 'Update Bank Details' : 'Update Contact Details',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 8),
          Text(
            isBank ? 'Enter your new bank account details below.' : 'Update your contact email or phone number.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          if (isBank) ...[
            AppTextField(
              controller: _beneficiaryNameCtrl,
              label: l.tr('beneficiary_name'),
              hint: 'Account holder name',
              prefixIcon: Icons.person_outline,
              validator: (v) => (v == null || v.length < 3) ? 'Min 3 characters' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _accountNumberCtrl,
              label: l.tr('account_number'),
              hint: 'Enter new account number',
              prefixIcon: Icons.numbers,
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.length < 9 || v.length > 18) ? '9-18 digits required' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _ifscCtrl,
              label: l.tr('ifsc_code'),
              hint: 'HDFC0001234',
              prefixIcon: Icons.code,
              validator: (v) => (v == null || !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.toUpperCase())) ? 'Invalid IFSC format' : null,
            ),
          ] else ...[
            AppTextField(
              controller: _contactEmailCtrl,
              label: l.tr('email'),
              hint: 'contact@example.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _contactPhoneCtrl,
              label: l.tr('phone_number'),
              hint: '9876543210',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || !RegExp(r'^[6-9]\d{9}$').hasMatch(v)) ? 'Valid 10-digit phone' : null,
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: TextStyle(color: AppColors.error)),
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => setState(() { _screenState = 'view'; _error = null; }),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(l.tr('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  text: 'Save Changes',
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : () {
                    if (!_formKey.currentState!.validate()) return;
                    if (isBank) {
                      _updateDetails({
                        'bank_account_number': _accountNumberCtrl.text.trim(),
                        'bank_ifsc': _ifscCtrl.text.trim().toUpperCase(),
                        'bank_beneficiary_name': _beneficiaryNameCtrl.text.trim(),
                      });
                    } else {
                      _updateDetails({
                        'contact_email': _contactEmailCtrl.text.trim(),
                        'contact_phone': _contactPhoneCtrl.text.trim(),
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────── SETUP FORM (New Account) ────────────────

  Widget _buildSetupForm() {
    final l = context.watch<LocaleProvider>();
    return Form(
      key: _formKey,
      child: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep++);
          } else {
            _submitOnboarding();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                AppButton(
                  text: _currentStep == 2
                      ? (_isSubmitting ? 'Submitting...' : l.tr('submit'))
                      : l.tr('continue_text'),
                  onPressed: _isSubmitting ? null : details.onStepContinue,
                  isLoading: _isSubmitting && _currentStep == 2,
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(onPressed: details.onStepCancel, child: Text(l.tr('back'))),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text(l.tr('business_details')),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                TextFormField(
                  controller: _businessNameCtrl,
                  decoration: InputDecoration(labelText: l.tr('legal_business_name'), prefixIcon: const Icon(Icons.business)),
                  validator: (v) => (v == null || v.length < 3) ? 'Min 3 characters' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _businessType,
                  decoration: InputDecoration(labelText: l.tr('business_type'), prefixIcon: const Icon(Icons.category)),
                  items: const [
                    DropdownMenuItem(value: 'individual', child: Text('Individual')),
                    DropdownMenuItem(value: 'proprietorship', child: Text('Proprietorship')),
                    DropdownMenuItem(value: 'partnership', child: Text('Partnership')),
                    DropdownMenuItem(value: 'private_limited', child: Text('Private Limited')),
                    DropdownMenuItem(value: 'llp', child: Text('LLP')),
                  ],
                  onChanged: (v) => setState(() => _businessType = v ?? 'individual'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactNameCtrl,
                  decoration: InputDecoration(labelText: l.tr('contact_name'), prefixIcon: const Icon(Icons.person)),
                  validator: (v) => (v == null || v.length < 2) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactEmailCtrl,
                  decoration: InputDecoration(labelText: l.tr('email'), prefixIcon: const Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactPhoneCtrl,
                  decoration: InputDecoration(labelText: l.tr('phone_number'), prefixIcon: const Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) => (v == null || !RegExp(r'^[6-9]\d{9}$').hasMatch(v)) ? 'Valid 10-digit phone' : null,
                ),
              ],
            ),
          ),
          Step(
            title: Text(l.tr('kyc_details')),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                TextFormField(
                  controller: _panCtrl,
                  decoration: InputDecoration(labelText: l.tr('pan_number'), hintText: 'ABCDE1234F', prefixIcon: const Icon(Icons.credit_card)),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                  validator: (v) => (v == null || !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v.toUpperCase())) ? 'Invalid PAN format' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gstCtrl,
                  decoration: InputDecoration(labelText: '${l.tr('gst_number')} (Optional)', prefixIcon: const Icon(Icons.receipt_long)),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 15,
                ),
              ],
            ),
          ),
          Step(
            title: Text(l.tr('bank_details')),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                TextFormField(
                  controller: _accountNumberCtrl,
                  decoration: InputDecoration(labelText: l.tr('account_number'), prefixIcon: const Icon(Icons.numbers)),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.length < 9 || v.length > 18) ? '9-18 digits required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ifscCtrl,
                  decoration: InputDecoration(labelText: l.tr('ifsc_code'), hintText: 'HDFC0001234', prefixIcon: const Icon(Icons.code)),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 11,
                  validator: (v) => (v == null || !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.toUpperCase())) ? 'Invalid IFSC format' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _beneficiaryNameCtrl,
                  decoration: InputDecoration(labelText: l.tr('beneficiary_name'), prefixIcon: const Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.length < 3) ? 'Min 3 characters' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 13))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _panCtrl.dispose();
    _gstCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _beneficiaryNameCtrl.dispose();
    super.dispose();
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});
}
