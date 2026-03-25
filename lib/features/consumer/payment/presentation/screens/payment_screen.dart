import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../core/utils/storage_service.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final double amount;
  final String salonName;
  final String paymentType; // 'full' or 'token'

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.salonName,
    this.paymentType = 'full',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  late Razorpay _razorpay;

  bool _isCreatingOrder = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _createOrderAndPay() async {
    setState(() => _isCreatingOrder = true);

    try {
      final response = await _api.post(
        ApiConfig.createPaymentOrder,
        body: {
          'booking_id': widget.bookingId,
          'payment_type': widget.paymentType,
        },
      );

      final data = response['data'] ?? {};
      final orderId = data['order_id'] ?? data['orderId'] ?? '';
      final amountInPaise = data['amount'] ?? (widget.amount * 100).toInt();

      if (orderId.toString().isEmpty) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Failed to create payment order');
        }
        setState(() => _isCreatingOrder = false);
        return;
      }

      // Get user details for prefill
      final user = _storage.getUser();
      final email = user?['email'] ?? '';
      final phone = user?['phone'] ?? user?['phoneNumber'] ?? '';

      final options = {
        'key': data['key_id'] ?? data['razorpay_key'] ?? data['key'] ?? '',
        'amount': amountInPaise,
        'name': 'Saloon',
        'description': widget.salonName,
        'order_id': orderId,
        'prefill': {
          'email': email,
          'contact': phone,
        },
        'theme': {
          'color': '#1F6A63',
        },
      };

      setState(() => _isCreatingOrder = false);
      _razorpay.open(options);
    } on ApiException catch (e) {
      setState(() => _isCreatingOrder = false);
      if (mounted) SnackbarUtils.showError(context, e.message);
    } catch (e) {
      setState(() => _isCreatingOrder = false);
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to initiate payment');
      }
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isVerifying = true);

    try {
      await _api.post(
        ApiConfig.verifyPayment,
        body: {
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
        },
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showSuccessDialog();
    } on ApiException catch (e) {
      setState(() => _isVerifying = false);
      if (mounted) {
        _showErrorDialog(
          'We received your payment but verification failed. Don\'t worry — your money is safe. If the amount was deducted, it will be auto-refunded within 5-7 days, or you can contact support.',
          false,
        );
      }
    } catch (_) {
      setState(() => _isVerifying = false);
      if (mounted) {
        _showErrorDialog(
          'Payment verification could not be completed due to a network issue. Your payment is safe — please check your booking status or contact support if the amount was deducted.',
          false,
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    final code = response.code;
    String message;

    // User-friendly error messages based on Razorpay error codes
    switch (code) {
      case 0: // NETWORK_ERROR
        message = 'Network error. Please check your internet connection and try again.';
        break;
      case 1: // INVALID_OPTIONS
        message = 'Something went wrong with the payment setup. Please try again.';
        break;
      case 2: // PAYMENT_CANCELLED
        message = 'Payment was cancelled. You can try again whenever you\'re ready.';
        break;
      case 3: // TLS_ERROR
        message = 'Secure connection failed. Please update your app and try again.';
        break;
      case 4: // INCOMPATIBLE_PLUGIN
        message = 'Payment service is temporarily unavailable. Please try again later.';
        break;
      default:
        message = 'Payment could not be completed. Please try again or use a different payment method.';
    }

    _showErrorDialog(message, code == 2);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    SnackbarUtils.showInfo(
      context,
      'Redirecting to ${response.walletName}...',
    );
  }

  void _showErrorDialog(String message, bool wasCancelled) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: wasCancelled
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                wasCancelled ? Icons.cancel_outlined : Icons.error_outline,
                color: wasCancelled ? Colors.orange : Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              wasCancelled ? 'Payment Cancelled' : 'Payment Failed',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, false);
                    },
                    child: const Text('Go Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: 'Retry',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _createOrderAndPay();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    final isToken = widget.paymentType == 'token';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment Successful!',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment of \u20B9${widget.amount.toStringAsFixed(0)} to ${widget.salonName} has been received.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (isToken) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Token paid. Remaining amount to be paid at the salon.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isToken) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fully paid. No additional charges at the salon.',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade800, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'You will receive a confirmation notification shortly.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'View Booking',
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _isCreatingOrder || _isVerifying;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment summary card
                  _buildPaymentSummaryCard(),
                  const SizedBox(height: 16),

                  // Payment type info
                  _buildPaymentTypeCard(),
                  const SizedBox(height: 16),

                  // Secure payment note
                  _buildSecurePaymentNote(),
                ],
              ),
            ),
          ),

          // Pay Now button
          _buildPayButton(isProcessing),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard() {
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.store,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.salonName,
                      style: AppTextStyles.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Booking #${widget.bookingId.length > 8 ? widget.bookingId.substring(widget.bookingId.length - 8) : widget.bookingId}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          // Amount row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Service Amount',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '\u20B9${widget.amount.toStringAsFixed(0)}',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Payment type row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Type',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.paymentType == 'full'
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.accentLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.paymentType == 'full'
                      ? 'Full Payment'
                      : 'Token Payment',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.paymentType == 'full'
                        ? AppColors.primary
                        : AppColors.accentDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          // Total payable
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Payable', style: AppTextStyles.h4),
              Text(
                '\u20B9${widget.amount.toStringAsFixed(0)}',
                style: AppTextStyles.h3.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeCard() {
    final isToken = widget.paymentType == 'token';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isToken ? AppColors.warningLight : AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToken
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isToken ? Icons.info_outline : Icons.verified_outlined,
            color: isToken ? AppColors.accentDark : AppColors.success,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isToken
                  ? 'This is a token payment to confirm your booking. The remaining amount will be collected at the salon.'
                  : 'This is the full payment for your booking. No additional charges at the salon.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isToken ? AppColors.accentDark : AppColors.success,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurePaymentNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Powered by Razorpay. Your payment information is encrypted and secure.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton(bool isProcessing) {
    String buttonText;
    if (_isCreatingOrder) {
      buttonText = 'Creating Order...';
    } else if (_isVerifying) {
      buttonText = 'Verifying Payment...';
    } else {
      buttonText = 'Pay \u20B9${widget.amount.toStringAsFixed(0)}';
    }

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
          text: buttonText,
          onPressed: isProcessing ? null : _createOrderAndPay,
          isLoading: isProcessing,
          icon: isProcessing ? null : Icons.payment,
        ),
      ),
    );
  }
}
