import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../../../config/api_config.dart';
import '../../../../../core/i18n/locale_provider.dart';
import '../../../../../core/utils/storage_service.dart';

/// Multi-step onboarding screen for salon owners to set up Razorpay Route.
/// Collects business details, KYC (PAN), and bank account info.
class PaymentSetupScreen extends StatefulWidget {
  final String salonId;
  const PaymentSetupScreen({super.key, required this.salonId});

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;
  bool _isComplete = false;

  // Business details
  final _businessNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  String _businessType = 'individual';

  // KYC
  final _panController = TextEditingController();
  final _gstController = TextEditingController();

  // Bank details
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _beneficiaryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkExistingAccount();
  }

  Future<void> _checkExistingAccount() async {
    setState(() => _isLoading = true);
    try {
      final token = await StorageService().getAccessToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.linkedAccount(widget.salonId)}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        if (data != null) {
          setState(() => _isComplete = true);
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _error = null; });

    try {
      final token = await StorageService().getAccessToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.linkedAccount(widget.salonId)}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'legal_business_name': _businessNameController.text.trim(),
          'business_type': _businessType,
          'contact_name': _contactNameController.text.trim(),
          'contact_email': _contactEmailController.text.trim(),
          'contact_phone': _contactPhoneController.text.trim(),
          'pan': _panController.text.trim().toUpperCase(),
          if (_gstController.text.trim().isNotEmpty)
            'gst': _gstController.text.trim().toUpperCase(),
          'bank_account_number': _accountNumberController.text.trim(),
          'bank_ifsc': _ifscController.text.trim().toUpperCase(),
          'bank_beneficiary_name': _beneficiaryNameController.text.trim(),
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() => _isComplete = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.read<LocaleProvider>().tr('payment_setup_success')), backgroundColor: Colors.green),
          );
        }
      } else {
        setState(() => _error = body['message'] ?? 'Failed to submit');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    try {
      final token = await StorageService().getAccessToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.refreshKycStatus(widget.salonId)}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && mounted) {
        final data = body['data'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status: ${data['kyc_status']} (Razorpay: ${data['razorpay_status']})')),
        );
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l.tr('payment_setup'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isComplete
              ? _buildCompleteView()
              : _buildSetupForm(),
    );
  }

  Widget _buildCompleteView() {
    final l = context.watch<LocaleProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(l.tr('payment_setup_submitted'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l.tr('kyc_in_progress'), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshStatus,
              icon: const Icon(Icons.refresh),
              label: Text(l.tr('refresh_status')),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.tr('go_back'))),
          ],
        ),
      ),
    );
  }

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
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(_currentStep == 2 ? l.tr('submit') : l.tr('continue_text')),
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
            content: Column(
              children: [
                TextFormField(
                  controller: _businessNameController,
                  decoration: InputDecoration(labelText: l.tr('legal_business_name')),
                  validator: (v) => (v == null || v.length < 3) ? 'Min 3 characters' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _businessType,
                  decoration: InputDecoration(labelText: l.tr('business_type')),
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
                  controller: _contactNameController,
                  decoration: InputDecoration(labelText: l.tr('contact_name')),
                  validator: (v) => (v == null || v.length < 2) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactEmailController,
                  decoration: InputDecoration(labelText: l.tr('email')),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactPhoneController,
                  decoration: InputDecoration(labelText: l.tr('phone_number')),
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
            content: Column(
              children: [
                TextFormField(
                  controller: _panController,
                  decoration: InputDecoration(labelText: l.tr('pan_number'), hintText: 'ABCDE1234F'),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                  validator: (v) => (v == null || !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v.toUpperCase())) ? 'Invalid PAN format' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gstController,
                  decoration: InputDecoration(labelText: l.tr('gst_number')),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 15,
                ),
              ],
            ),
          ),
          Step(
            title: Text(l.tr('bank_details')),
            isActive: _currentStep >= 2,
            content: Column(
              children: [
                TextFormField(
                  controller: _accountNumberController,
                  decoration: InputDecoration(labelText: l.tr('account_number')),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.length < 9 || v.length > 18) ? '9-18 digits required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ifscController,
                  decoration: InputDecoration(labelText: l.tr('ifsc_code'), hintText: 'HDFC0001234'),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 11,
                  validator: (v) => (v == null || !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.toUpperCase())) ? 'Invalid IFSC format' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _beneficiaryNameController,
                  decoration: InputDecoration(labelText: l.tr('beneficiary_name')),
                  validator: (v) => (v == null || v.length < 3) ? 'Min 3 characters' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
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
    _businessNameController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _panController.dispose();
    _gstController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _beneficiaryNameController.dispose();
    super.dispose();
  }
}
