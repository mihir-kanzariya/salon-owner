import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../providers/auth_provider.dart';
import '../../../salon/providers/salon_provider.dart';

/// Test accounts — always visible for now (testing phase).
const _devMode = true;

const _testAccounts = [
  {'phone': '9999999001', 'name': 'Arjun Mehta', 'role': 'Salon Owner', 'salon': 'Urban Edge Salon', 'icon': Icons.store},
  {'phone': '9999999002', 'name': 'Priya Sharma', 'role': 'Salon Owner', 'salon': 'Glamour Studio', 'icon': Icons.store},
  {'phone': '9999999003', 'name': 'Rahul Verma', 'role': 'Customer', 'salon': '', 'icon': Icons.person},
  {'phone': '9999999004', 'name': 'Sneha Patel', 'role': 'Customer', 'salon': '', 'icon': Icons.person},
  {'phone': '9999999005', 'name': 'Vikram Singh', 'role': 'Stylist', 'salon': 'Urban Edge Salon', 'icon': Icons.content_cut},
  {'phone': '9999999006', 'name': 'Anita Desai', 'role': 'Stylist', 'salon': 'Glamour Studio', 'icon': Icons.content_cut},
];

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _quickLogging = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AuthProvider>();
    final success = await provider.sendOtp(_phoneController.text.trim());

    if (!mounted) return;

    if (success) {
      Navigator.pushNamed(context, '/otp');
    } else {
      SnackbarUtils.showError(context, provider.error);
    }
  }

  Future<void> _quickLogin(String phone) async {
    if (_quickLogging) return;
    setState(() => _quickLogging = true);

    final provider = context.read<AuthProvider>();

    // Step 1: Send OTP
    final sent = await provider.sendOtp(phone);
    if (!mounted) return;
    if (!sent) {
      SnackbarUtils.showError(context, provider.error);
      setState(() => _quickLogging = false);
      return;
    }

    // Step 2: Auto-verify with test OTP
    final verified = await provider.verifyOtp('1111');
    if (!mounted) return;

    setState(() => _quickLogging = false);

    if (verified) {
      if (provider.state == AuthState.profileIncomplete) {
        Navigator.pushReplacementNamed(context, '/profile-setup');
      } else {
        final role = provider.user?.role ?? 'customer';
        if (role == 'salon_user') {
          await context.read<SalonProvider>().loadSalonData();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/salon-home');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } else {
      SnackbarUtils.showError(context, provider.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Text('Welcome to', style: AppTextStyles.bodyLarge),
                const Text('Saloon', style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(
                  'Enter your mobile number to continue',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 18, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '9876543210',
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('+91', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            height: 24,
                            width: 1,
                            color: AppColors.border,
                          ),
                        ],
                      ),
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your mobile number';
                    if (value.length != 10) return 'Mobile number must be 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return AppButton(
                      text: 'Send OTP',
                      onPressed: _sendOtp,
                      isLoading: auth.state == AuthState.loading && !_quickLogging,
                    );
                  },
                ),

                // --- Dev Quick Login ---
                if (_devMode) ...[
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            'DEV TEST ACCOUNTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to quick-login (OTP: 1111)',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (_quickLogging)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ..._testAccounts.map((account) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _quickLogin(account['phone'] as String),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _roleColor(account['role'] as String).withValues(alpha: 0.15),
                                  child: Icon(
                                    account['icon'] as IconData,
                                    size: 20,
                                    color: _roleColor(account['role'] as String),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account['name'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            account['phone'] as String,
                                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                                          ),
                                          if ((account['salon'] as String).isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text('•', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                account['salon'] as String,
                                                style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _roleColor(account['role'] as String).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    account['role'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _roleColor(account['role'] as String),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
                ],

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Salon Owner':
        return AppColors.primary;
      case 'Customer':
        return Colors.blue;
      case 'Stylist':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }
}
