import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../../../config/api_config.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/utils/storage_service.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';

// ---------------------------------------------------------------------------
// Payment Setup Screen
//
// States: loading -> setup (3-step form) | view (read-only) | edit | success
// ---------------------------------------------------------------------------

class PaymentSetupScreen extends StatefulWidget {
  final String salonId;
  const PaymentSetupScreen({super.key, required this.salonId});

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

enum _ScreenState { loading, setup, view, editBank, editContact, success }

class _PaymentSetupScreenState extends State<PaymentSetupScreen>
    with TickerProviderStateMixin {
  // -- state ---
  _ScreenState _state = _ScreenState.loading;
  bool _isSubmitting = false;
  String? _error;
  Map<String, dynamic>? _accountData;

  // -- success details (shown on success screen) --
  String _successBusinessName = '';
  String _successPan = '';
  String _successIfsc = '';

  // -- form --
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
  final _confirmAccountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _beneficiaryNameCtrl = TextEditingController();

  // -- edit form --
  final _editFormKey = GlobalKey<FormState>();

  // -- success animation --
  late AnimationController _checkAnimCtrl;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = CurvedAnimation(
      parent: _checkAnimCtrl,
      curve: Curves.elasticOut,
    );
    _loadExistingAccount();
  }

  @override
  void dispose() {
    _checkAnimCtrl.dispose();
    _businessNameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _panCtrl.dispose();
    _gstCtrl.dispose();
    _accountNumberCtrl.dispose();
    _confirmAccountCtrl.dispose();
    _ifscCtrl.dispose();
    _beneficiaryNameCtrl.dispose();
    super.dispose();
  }

  // ======================= API =============================================

  Future<String?> _getToken() async => StorageService().getAccessToken();

  Future<void> _loadExistingAccount() async {
    setState(() {
      _state = _ScreenState.loading;
      _error = null;
    });
    try {
      final token = await _getToken();
      final url =
          '${ApiConfig.baseUrl}${ApiConfig.linkedAccount(widget.salonId)}';
      debugPrint('[PaymentSetup] Loading: $url');
      final res = await http
          .get(Uri.parse(url),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      debugPrint('[PaymentSetup] Status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'];
        if (data != null && body['success'] == true) {
          _accountData = data;
          _state = _ScreenState.view;
        } else {
          _state = _ScreenState.setup;
        }
      } else {
        _state = _ScreenState.setup;
      }
    } on TimeoutException {
      _state = _ScreenState.setup;
      _error = 'request_timeout';
    } catch (e) {
      _state = _ScreenState.setup;
      debugPrint('[PaymentSetup] Error: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final token = await _getToken();
      final res = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.linkedAccount(widget.salonId)}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'legal_business_name': _businessNameCtrl.text.trim(),
              'business_type': _businessType,
              'contact_name': _contactNameCtrl.text.trim(),
              'contact_email': _contactEmailCtrl.text.trim(),
              'contact_phone': _contactPhoneCtrl.text.trim(),
              if (_panCtrl.text.trim().isNotEmpty)
                'pan': _panCtrl.text.trim().toUpperCase(),
              if (_gstCtrl.text.trim().isNotEmpty)
                'gst': _gstCtrl.text.trim().toUpperCase(),
              'bank_account_number': _accountNumberCtrl.text.trim(),
              'bank_ifsc': _ifscCtrl.text.trim().toUpperCase(),
              'bank_beneficiary_name': _beneficiaryNameCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        _successBusinessName = _businessNameCtrl.text.trim();
        _successPan = _panCtrl.text.trim().toUpperCase();
        _successIfsc = _ifscCtrl.text.trim().toUpperCase();
        setState(() {
          _state = _ScreenState.success;
          _isSubmitting = false;
        });
        _checkAnimCtrl.forward(from: 0);
      } else {
        setState(() {
          _error = _mapBackendError(body['message'] ?? 'Failed to submit');
          _isSubmitting = false;
        });
      }
    } on TimeoutException {
      setState(() {
        _error = 'request_timeout';
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'network_error';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _updateDetails(Map<String, dynamic> updateData) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final token = await _getToken();
      final res = await http
          .put(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.linkedAccount(widget.salonId)}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(updateData),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _showSnackBar('details_updated_success', isSuccess: true);
        await _loadExistingAccount();
      } else {
        setState(
            () => _error = body['message'] ?? 'error_occurred');
      }
    } on TimeoutException {
      setState(() => _error = 'request_timeout');
    } catch (e) {
      setState(() => _error = 'network_error');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _refreshKycStatus() async {
    setState(() => _state = _ScreenState.loading);
    try {
      final token = await _getToken();
      await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.refreshKycStatus(widget.salonId)}'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
      await _loadExistingAccount();
      return;
    } catch (_) {}
    if (mounted) await _loadExistingAccount();
  }

  String _mapBackendError(String msg) {
    if (msg.contains('profile field is required')) {
      return 'ps_err_profile_address';
    } else if (msg.contains('The email has already been used')) {
      return 'ps_err_email_exists';
    } else if (msg.contains('Invalid PAN')) {
      return 'ps_err_invalid_pan';
    } else if (msg.contains('Invalid IFSC') || msg.contains('ifsc')) {
      return 'ps_err_invalid_ifsc';
    } else if (msg.contains('postal_code')) {
      return 'ps_err_pincode';
    } else if (msg.contains('account_number') || msg.contains('bank')) {
      return 'ps_err_bank_details';
    } else if (msg.contains('already exists') || msg.contains('duplicate')) {
      return 'ps_err_already_exists';
    } else if (msg.contains('Access Denied')) {
      return 'ps_err_route_not_active';
    }
    return msg;
  }

  // ======================= HELPERS =========================================

  String _mask(String? value, {int visible = 4}) {
    if (value == null || value.isEmpty) return '-';
    if (value.length <= visible) return value;
    final dots = '\u2022' * (value.length - visible);
    return '$dots${value.substring(value.length - visible)}';
  }

  void _showSnackBar(String key, {bool isSuccess = false}) {
    if (!mounted) return;
    final l = context.read<LocaleProvider>();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.tr(key)),
      backgroundColor: isSuccess ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _businessNameCtrl.text.trim().length >= 3 &&
            _contactNameCtrl.text.trim().length >= 2 &&
            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                .hasMatch(_contactEmailCtrl.text.trim()) &&
            RegExp(r'^[6-9]\d{9}$').hasMatch(_contactPhoneCtrl.text.trim());
      case 1:
        // PAN and GST are optional
        final pan = _panCtrl.text.trim();
        if (pan.isNotEmpty &&
            !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan.toUpperCase())) {
          return false;
        }
        final gst = _gstCtrl.text.trim();
        if (gst.isNotEmpty && gst.length != 15) {
          return false;
        }
        return true;
      case 2:
        final accNum = _accountNumberCtrl.text.trim();
        return accNum.length >= 9 &&
            accNum.length <= 18 &&
            _confirmAccountCtrl.text.trim() == accNum &&
            RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                .hasMatch(_ifscCtrl.text.trim().toUpperCase()) &&
            _beneficiaryNameCtrl.text.trim().length >= 3;
      default:
        return true;
    }
  }

  // ======================= BUILD ==========================================

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _state == _ScreenState.success
          ? null
          : AppBar(
              title: Text(l.tr('payment_setup')),
              actions: [
                if (_state == _ScreenState.view)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshKycStatus,
                    tooltip: l.tr('refresh_status'),
                  ),
              ],
            ),
      body: Stack(
        children: [
          _buildBody(l),
          // Full-screen loading overlay during submission
          if (_isSubmitting) _buildLoadingOverlay(l),
        ],
      ),
    );
  }

  Widget _buildBody(LocaleProvider l) {
    switch (_state) {
      case _ScreenState.loading:
        return const Center(child: CircularProgressIndicator());
      case _ScreenState.setup:
        return _buildSetupForm(l);
      case _ScreenState.view:
        return _buildViewState(l);
      case _ScreenState.editBank:
      case _ScreenState.editContact:
        return _buildEditState(l);
      case _ScreenState.success:
        return _buildSuccessScreen(l);
    }
  }

  // =================== LOADING OVERLAY =====================================

  Widget _buildLoadingOverlay(LocaleProvider l) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 20),
              Text(
                l.tr('ps_setting_up'),
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l.tr('ps_please_wait'),
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =================== SUCCESS SCREEN ======================================

  Widget _buildSuccessScreen(LocaleProvider l) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Animated checkmark
            ScaleTransition(
              scale: _checkScale,
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 56),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l.tr('ps_setup_complete'),
              style: AppTextStyles.h1.copyWith(color: AppColors.success),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Submitted details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.tr('ps_submitted_details'),
                      style: AppTextStyles.labelLarge),
                  const SizedBox(height: 16),
                  _detailRow(l.tr('legal_business_name'), _successBusinessName),
                  const SizedBox(height: 10),
                  _detailRow(l.tr('pan_number'),
                      _successPan.isEmpty ? '-' : _mask(_successPan)),
                  const SizedBox(height: 10),
                  _detailRow(l.tr('ifsc_code'), _successIfsc),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // KYC note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.tr('ps_kyc_timeframe'),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Buttons
            AppButton(
              text: l.tr('ps_check_status'),
              icon: Icons.refresh,
              onPressed: () async {
                await _loadExistingAccount();
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              text: l.tr('go_back'),
              isOutlined: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        Flexible(
          child: Text(value,
              style:
                  AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }

  // =================== VIEW STATE ==========================================

  Widget _buildViewState(LocaleProvider l) {
    final d = _accountData!;
    final kycStatus = d['kyc_status'] ?? 'pending';
    final accountStatus = d['status'] ?? 'created';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildKycBanner(l, kycStatus, accountStatus),
        const SizedBox(height: 16),
        // Business Details Card
        _buildInfoCard(
          title: l.tr('business_details'),
          icon: Icons.business,
          items: [
            _InfoItem(
                label: l.tr('legal_business_name'),
                value: d['legal_business_name'] ?? '-'),
            _InfoItem(
                label: l.tr('business_type'),
                value: _formatBusinessType(
                    l, d['business_type']?.toString() ?? '-')),
          ],
        ),
        const SizedBox(height: 12),
        // Contact Details Card
        _buildInfoCard(
          title: l.tr('ps_contact_details'),
          icon: Icons.person,
          onEdit: () {
            _contactEmailCtrl.text = d['contact_email'] ?? '';
            _contactPhoneCtrl.text = d['contact_phone'] ?? '';
            setState(() => _state = _ScreenState.editContact);
          },
          items: [
            _InfoItem(
                label: l.tr('contact_name'),
                value: d['contact_name'] ?? '-'),
            _InfoItem(
                label: l.tr('email'), value: d['contact_email'] ?? '-'),
            _InfoItem(
                label: l.tr('phone_number'),
                value: d['contact_phone'] ?? '-'),
          ],
        ),
        const SizedBox(height: 12),
        // Bank Details Card
        _buildInfoCard(
          title: l.tr('bank_details'),
          icon: Icons.account_balance,
          onEdit: () {
            _accountNumberCtrl.text = '';
            _confirmAccountCtrl.text = '';
            _ifscCtrl.text = d['bank_ifsc'] ?? '';
            _beneficiaryNameCtrl.text = d['bank_beneficiary_name'] ?? '';
            setState(() => _state = _ScreenState.editBank);
          },
          items: [
            _InfoItem(
                label: l.tr('beneficiary_name'),
                value: d['bank_beneficiary_name'] ?? '-'),
            _InfoItem(
                label: l.tr('ifsc_code'), value: d['bank_ifsc'] ?? '-'),
            _InfoItem(
                label: l.tr('account_number'),
                value: _mask(d['bank_account_number'])),
          ],
        ),
        const SizedBox(height: 24),
        AppButton(
          text: l.tr('refresh_status'),
          isOutlined: true,
          icon: Icons.refresh,
          onPressed: _refreshKycStatus,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildKycBanner(
      LocaleProvider l, String kycStatus, String accountStatus) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String titleKey;
    String subtitleKey;

    switch (kycStatus) {
      case 'verified':
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.verified;
        titleKey = 'kyc_verified';
        subtitleKey = 'ps_kyc_active_msg';
        break;
      case 'failed':
        bgColor = AppColors.errorLight;
        textColor = AppColors.error;
        icon = Icons.error_outline;
        titleKey = 'kyc_failed';
        subtitleKey = 'ps_kyc_failed_msg';
        break;
      default:
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.hourglass_empty;
        titleKey = 'kyc_pending';
        subtitleKey = 'ps_kyc_pending_msg';
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
                Text(l.tr(titleKey),
                    style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 4),
                Text(l.tr(subtitleKey),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: textColor.withValues(alpha: 0.8))),
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
    final l = context.read<LocaleProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w700))),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(l.tr('edit')),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const Divider(height: 20),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    Flexible(
                        child: Text(item.value,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w500),
                            textAlign: TextAlign.end)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _formatBusinessType(LocaleProvider l, String type) {
    switch (type) {
      case 'individual':
        return l.tr('ps_bt_individual');
      case 'proprietorship':
        return l.tr('ps_bt_proprietorship');
      case 'partnership':
        return l.tr('ps_bt_partnership');
      case 'private_limited':
        return l.tr('ps_bt_private_limited');
      case 'llp':
        return l.tr('ps_bt_llp');
      default:
        return type.replaceAll('_', ' ');
    }
  }

  // =================== EDIT STATE ==========================================

  Widget _buildEditState(LocaleProvider l) {
    final isBank = _state == _ScreenState.editBank;

    return Form(
      key: _editFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.tr(isBank ? 'ps_update_bank' : 'ps_update_contact'),
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 8),
          Text(
            l.tr(isBank ? 'ps_update_bank_desc' : 'ps_update_contact_desc'),
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (isBank) ...[
            AppTextField(
              controller: _beneficiaryNameCtrl,
              label: l.tr('beneficiary_name'),
              hint: l.tr('ps_holder_name_hint'),
              prefixIcon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().length < 3)
                  ? l.tr('ps_err_min_3_chars')
                  : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _accountNumberCtrl,
              label: l.tr('account_number'),
              hint: l.tr('ps_account_hint'),
              prefixIcon: Icons.numbers,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 18,
              validator: (v) => (v == null || v.length < 9 || v.length > 18)
                  ? l.tr('ps_err_account_digits')
                  : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _ifscCtrl,
              label: l.tr('ifsc_code'),
              hint: 'HDFC0001234',
              prefixIcon: Icons.code,
              maxLength: 11,
              inputFormatters: [UpperCaseTextFormatter()],
              validator: (v) =>
                  (v == null ||
                          !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                              .hasMatch(v.toUpperCase()))
                      ? l.tr('ps_err_invalid_ifsc_fmt')
                      : null,
            ),
          ] else ...[
            AppTextField(
              controller: _contactEmailCtrl,
              label: l.tr('email'),
              hint: 'contact@example.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(v.trim()))
                      ? l.tr('ps_err_valid_email')
                      : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _contactPhoneCtrl,
              label: l.tr('phone_number'),
              hint: '9876543210',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  (v == null || !RegExp(r'^[6-9]\d{9}$').hasMatch(v))
                      ? l.tr('ps_err_valid_phone')
                      : null,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildErrorBanner(l),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: l.tr('cancel'),
                  isOutlined: true,
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _state = _ScreenState.view;
                            _error = null;
                          }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  text: l.tr('ps_save_changes'),
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (!_editFormKey.currentState!.validate()) return;
                          if (isBank) {
                            _updateDetails({
                              'bank_account_number':
                                  _accountNumberCtrl.text.trim(),
                              'bank_ifsc':
                                  _ifscCtrl.text.trim().toUpperCase(),
                              'bank_beneficiary_name':
                                  _beneficiaryNameCtrl.text.trim(),
                            });
                          } else {
                            _updateDetails({
                              'contact_email':
                                  _contactEmailCtrl.text.trim(),
                              'contact_phone':
                                  _contactPhoneCtrl.text.trim(),
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

  // =================== SETUP FORM (3 STEPS) ================================

  Widget _buildSetupForm(LocaleProvider l) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // -- Progress indicator --
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            color: AppColors.background,
            child: _buildProgressIndicator(l),
          ),
          const SizedBox(height: 8),
          // -- Error banner --
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildErrorBanner(l),
            ),
          // -- Form content --
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_currentStep == 0) _buildStep1(l),
                if (_currentStep == 1) _buildStep2(l),
                if (_currentStep == 2) _buildStep3(l),
              ],
            ),
          ),
          // -- Bottom buttons --
          _buildBottomButtons(l),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(LocaleProvider l) {
    return Row(
      children: [
        _stepCircle(0, l.tr('business_details')),
        Expanded(child: _stepLine(0)),
        _stepCircle(1, l.tr('kyc_details')),
        Expanded(child: _stepLine(1)),
        _stepCircle(2, l.tr('bank_details')),
      ],
    );
  }

  Widget _stepCircle(int step, String label) {
    final isActive = _currentStep >= step;
    final isComplete = _currentStep > step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.border,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check, color: AppColors.white, size: 18)
                : Text('${step + 1}',
                    style: TextStyle(
                        color:
                            isActive ? AppColors.white : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textMuted),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _stepLine(int beforeStep) {
    final isActive = _currentStep > beforeStep;
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isActive ? AppColors.primary : AppColors.border,
    );
  }

  // ---- Step 1: Business Details -------------------------------------------

  Widget _buildStep1(LocaleProvider l) {
    return _sectionCard(l.tr('business_details'), Icons.business, [
      AppTextField(
        controller: _businessNameCtrl,
        label: l.tr('legal_business_name'),
        hint: l.tr('ps_business_name_hint'),
        prefixIcon: Icons.business,
        validator: (v) => (v == null || v.trim().length < 3)
            ? l.tr('ps_err_min_3_chars')
            : null,
        onChanged: (_) => setState(() {}),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
        child: Text(l.tr('ps_pan_card_hint'),
            style: AppTextStyles.caption),
      ),
      const SizedBox(height: 4),
      // Business Type Dropdown
      DropdownButtonFormField<String>(
        initialValue: _businessType,
        decoration: InputDecoration(
          labelText: l.tr('business_type'),
          prefixIcon:
              const Icon(Icons.category, color: AppColors.textMuted, size: 20),
        ),
        items: [
          DropdownMenuItem(
              value: 'individual', child: Text(l.tr('ps_bt_individual'))),
          DropdownMenuItem(
              value: 'proprietorship',
              child: Text(l.tr('ps_bt_proprietorship'))),
          DropdownMenuItem(
              value: 'partnership', child: Text(l.tr('ps_bt_partnership'))),
          DropdownMenuItem(
              value: 'private_limited',
              child: Text(l.tr('ps_bt_private_limited'))),
          DropdownMenuItem(value: 'llp', child: Text(l.tr('ps_bt_llp'))),
        ],
        onChanged: (v) => setState(() => _businessType = v ?? 'individual'),
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _contactNameCtrl,
        label: l.tr('contact_name'),
        prefixIcon: Icons.person,
        validator: (v) => (v == null || v.trim().length < 2)
            ? l.tr('ps_err_min_2_chars')
            : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _contactEmailCtrl,
        label: l.tr('email'),
        hint: 'name@example.com',
        prefixIcon: Icons.email,
        keyboardType: TextInputType.emailAddress,
        validator: (v) =>
            (v == null ||
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                ? l.tr('ps_err_valid_email')
                : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _contactPhoneCtrl,
        label: l.tr('phone_number'),
        hint: '9876543210',
        prefixIcon: Icons.phone,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) =>
            (v == null || !RegExp(r'^[6-9]\d{9}$').hasMatch(v))
                ? l.tr('ps_err_valid_phone')
                : null,
        onChanged: (_) => setState(() {}),
      ),
    ]);
  }

  // ---- Step 2: KYC Details ------------------------------------------------

  Widget _buildStep2(LocaleProvider l) {
    return _sectionCard(l.tr('kyc_details'), Icons.credit_card, [
      AppTextField(
        controller: _panCtrl,
        label: l.tr('pan_number'),
        hint: 'ABCDE1234F',
        prefixIcon: Icons.credit_card,
        maxLength: 10,
        inputFormatters: [UpperCaseTextFormatter()],
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null; // optional
          if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$')
              .hasMatch(v.trim().toUpperCase())) {
            return l.tr('ps_err_invalid_pan_fmt');
          }
          return null;
        },
        onChanged: (_) => setState(() {}),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 12),
        child: Text(l.tr('ps_pan_optional_hint'),
            style: AppTextStyles.caption),
      ),
      AppTextField(
        controller: _gstCtrl,
        label: l.tr('gst_number'),
        prefixIcon: Icons.receipt_long,
        maxLength: 15,
        inputFormatters: [UpperCaseTextFormatter()],
        onChanged: (_) => setState(() {}),
      ),
    ]);
  }

  // ---- Step 3: Bank Account -----------------------------------------------

  Widget _buildStep3(LocaleProvider l) {
    return _sectionCard(l.tr('bank_details'), Icons.account_balance, [
      AppTextField(
        controller: _accountNumberCtrl,
        label: l.tr('account_number'),
        prefixIcon: Icons.numbers,
        keyboardType: TextInputType.number,
        maxLength: 18,
        obscureText: true,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) => (v == null || v.length < 9 || v.length > 18)
            ? l.tr('ps_err_account_digits')
            : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _confirmAccountCtrl,
        label: l.tr('ps_confirm_account'),
        prefixIcon: Icons.numbers,
        keyboardType: TextInputType.number,
        maxLength: 18,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          if (v == null || v.isEmpty) return l.tr('ps_err_confirm_account');
          if (v != _accountNumberCtrl.text) {
            return l.tr('ps_err_account_mismatch');
          }
          return null;
        },
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _ifscCtrl,
        label: l.tr('ifsc_code'),
        hint: 'HDFC0001234',
        prefixIcon: Icons.code,
        maxLength: 11,
        inputFormatters: [UpperCaseTextFormatter()],
        validator: (v) =>
            (v == null ||
                    !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$')
                        .hasMatch(v.toUpperCase()))
                ? l.tr('ps_err_invalid_ifsc_fmt')
                : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _beneficiaryNameCtrl,
        label: l.tr('beneficiary_name'),
        hint: l.tr('ps_holder_name_hint'),
        prefixIcon: Icons.person_outline,
        validator: (v) => (v == null || v.trim().length < 3)
            ? l.tr('ps_err_min_3_chars')
            : null,
        onChanged: (_) => setState(() {}),
      ),
    ]);
  }

  // ---- Bottom Buttons -----------------------------------------------------

  Widget _buildBottomButtons(LocaleProvider l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: AppButton(
                  text: l.tr('back'),
                  isOutlined: true,
                  onPressed: () => setState(() {
                    _currentStep--;
                    _error = null;
                  }),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppButton(
                text: _currentStep == 2
                    ? l.tr('submit')
                    : l.tr('continue_text'),
                isLoading: _isSubmitting,
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (_currentStep < 2) {
                          // Validate current step before proceeding
                          if (_formKey.currentState!.validate() &&
                              _validateCurrentStep()) {
                            setState(() {
                              _currentStep++;
                              _error = null;
                            });
                          } else {
                            _formKey.currentState!.validate();
                          }
                        } else {
                          _submitOnboarding();
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Error Banner -------------------------------------------------------

  Widget _buildErrorBanner(LocaleProvider l) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.tr(_error!),
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close, color: AppColors.error, size: 16),
          ),
        ],
      ),
    );
  }

  // ---- Shared Widgets -----------------------------------------------------

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.h4),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ===========================================================================
// Helpers
// ===========================================================================

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});
}

/// Forces text to uppercase as user types.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
