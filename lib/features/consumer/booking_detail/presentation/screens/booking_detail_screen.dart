import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/utils/snackbar_utils.dart';
import '../../../../../core/utils/time_utils.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';
import '../../../../chat/presentation/screens/chat_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  bool _isCancelling = false;
  bool _hasError = false;
  bool _paymentSheetShown = false;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final response = await _api.get(
        '${ApiConfig.bookings}/${widget.bookingId}',
      );
      _booking = response['data'];

      setState(() => _isLoading = false);

      // F.3: Auto-show payment prompt for completed + unpaid bookings
      _checkPaymentPrompt();
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String get _status => (_booking?['status'] ?? 'pending').toString().toLowerCase();

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
      case 'no_show':
        return AppColors.error;
      case 'in_progress':
        return AppColors.accent;
      default:
        return AppColors.textMuted;
    }
  }

  Color _statusBackgroundColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.primary.withValues(alpha: 0.1);
      case 'completed':
        return AppColors.successLight;
      case 'cancelled':
      case 'no_show':
        return AppColors.errorLight;
      case 'in_progress':
        return AppColors.warningLight;
      default:
        return AppColors.softSurface;
    }
  }

  String _statusDisplay(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'no_show':
        return 'No Show';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.task_alt;
      case 'cancelled':
      case 'no_show':
        return Icons.cancel_outlined;
      case 'in_progress':
        return Icons.hourglass_top;
      default:
        return Icons.schedule;
    }
  }

  void _checkPaymentPrompt() {
    if (_paymentSheetShown || !mounted || _booking == null) return;
    final status = (_booking!['status'] ?? '').toString().toLowerCase();
    final paymentStatus = (_booking!['payment_status'] ?? _booking!['paymentStatus'] ?? 'pending').toString().toLowerCase();
    if (status == 'completed' && paymentStatus == 'pending') {
      _paymentSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPaymentBottomSheet();
      });
    }
  }

  void _showPaymentBottomSheet() {
    final totalAmount = _booking?['total_amount'] ?? _booking?['totalAmount'] ?? 0;
    final salon = _booking?['salon'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.check_circle, color: AppColors.success, size: 48),
            const SizedBox(height: 16),
            Text('Your service is complete!', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Text(
              'Please pay \u20B9${_formatPrice(totalAmount)} to ${salon?['name'] ?? 'the salon'}',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToPayment();
                },
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('Pay Online', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("I'll pay at salon", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancellation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Booking',
          style: AppTextStyles.h4,
        ),
        content: Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No, Keep It',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Yes, Cancel',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _cancelBooking();
    }
  }

  Future<void> _cancelBooking() async {
    setState(() => _isCancelling = true);

    try {
      await _api.post(
        '${ApiConfig.bookings}/${widget.bookingId}/cancel',
      );

      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Booking cancelled successfully');
      _loadBooking();
    } on ApiException catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Failed to cancel booking. Please try again.');
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _navigateToReview() async {
    final salon = _booking?['salon'];
    final stylist = _booking?['stylist'];

    final result = await Navigator.pushNamed(
      context,
      '/submit-review',
      arguments: {
        'bookingId': widget.bookingId,
        'salonId': salon?['_id'] ?? salon?['id'] ?? '',
        'salonName': salon?['name'],
        'stylistId': stylist?['_id'] ?? stylist?['id'],
      },
    );

    if (result == true) {
      _loadBooking();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Booking Details'),
      ),
      body: _isLoading
          ? const BookingDetailSkeleton()
          : _hasError
              ? _buildErrorState()
              : _booking == null
                  ? _buildErrorState()
                  : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load booking',
              style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Retry',
              onPressed: _loadBooking,
              width: 140,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final status = _status;
    final salon = _booking!['salon'] as Map<String, dynamic>?;
    final services = _booking!['services'] as List<dynamic>? ?? [];
    final stylist = _booking!['stylist'] as Map<String, dynamic>?;
    final hasReview = _booking!['has_review'] == true || _booking!['review'] != null;
    final paymentStatus = (_booking!['payment_status'] ?? _booking!['paymentStatus'] ?? 'pending').toString().toLowerCase();
    final showPaymentBanner = status == 'completed' && paymentStatus == 'pending';

    return Column(
      children: [
        // F.3: Persistent payment pending banner
        if (showPaymentBanner)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.accent.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment pending — \u20B9${_formatPrice(_booking!['total_amount'] ?? _booking!['totalAmount'] ?? 0)}',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent),
                  ),
                ),
                TextButton(
                  onPressed: _navigateToPayment,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Pay Now', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBooking,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status banner
                  _buildStatusBanner(status),
                  const SizedBox(height: 16),

                  // Salon info card
                  if (salon != null) ...[
                    _buildSalonCard(salon),
                    const SizedBox(height: 12),
                  ],

                  // Booking details card
                  _buildBookingDetailsCard(),
                  const SizedBox(height: 12),

                  // Services list card
                  if (services.isNotEmpty) ...[
                    _buildServicesCard(services),
                    const SizedBox(height: 12),
                  ],

                  // Stylist card
                  if (stylist != null) ...[
                    _buildStylistCard(stylist),
                    const SizedBox(height: 12),
                  ],

                  // Message Salon button
                  if (_booking!['chat_room'] != null &&
                      _booking!['chat_room']['is_active'] == true)
                    ...[
                      _buildMessageSalonButton(),
                      const SizedBox(height: 12),
                    ],

                  // Payment card
                  _buildPaymentCard(),
                  const SizedBox(height: 12),

                  // F.4: Review prompt card for completed bookings without review
                  if (status == 'completed' && !hasReview)
                    Card(
                      color: AppColors.accent.withValues(alpha: 0.05),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _navigateToReview,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.accent, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('How was your visit?', style: AppTextStyles.labelLarge),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to leave a review',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // Action buttons at bottom
        _buildActionButtons(status, hasReview),
      ],
    );
  }

  Widget _buildStatusBanner(String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _statusBackgroundColor(status),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _statusColor(status).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _statusIcon(status),
            color: _statusColor(status),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusDisplay(status),
                  style: AppTextStyles.h4.copyWith(
                    color: _statusColor(status),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusSubtitle(status),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _statusColor(status).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusSubtitle(String status) {
    switch (status) {
      case 'confirmed':
        return 'Your booking has been confirmed';
      case 'completed':
        return 'This booking has been completed';
      case 'cancelled':
        return 'This booking was cancelled';
      case 'no_show':
        return 'You did not show up for this booking';
      case 'in_progress':
        return 'Your service is in progress';
      case 'pending':
        return 'Awaiting confirmation from the salon';
      default:
        return '';
    }
  }

  Widget _buildSalonCard(Map<String, dynamic> salon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryLight,
              child: const Icon(
                Icons.store,
                color: AppColors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    salon['name'] ?? 'Salon',
                    style: AppTextStyles.h4,
                  ),
                  if (salon['address'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            salon['address'] is Map
                                ? '${salon['address']['street'] ?? ''}, ${salon['address']['city'] ?? ''}'
                                : salon['address'].toString(),
                            style: AppTextStyles.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetailsCard() {
    final bookingNumber = _booking!['booking_number'] ?? _booking!['bookingNumber'] ?? '';
    final bookingDate = _booking!['booking_date'] ?? _booking!['bookingDate'] ?? '';
    final startTime = _booking!['start_time'] ?? _booking!['startTime'] ?? '';
    final endTime = _booking!['end_time'] ?? _booking!['endTime'] ?? '';
    final totalDuration = _booking!['total_duration_minutes'] ??
        _booking!['totalDurationMinutes'] ??
        0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Details', style: AppTextStyles.labelLarge),
            const SizedBox(height: 14),
            _buildDetailRow(
              Icons.confirmation_number_outlined,
              'Booking Number',
              '#$bookingNumber',
            ),
            const Divider(height: 20, color: AppColors.border),
            _buildDetailRow(
              Icons.calendar_today_outlined,
              'Date',
              bookingDate.toString(),
            ),
            const Divider(height: 20, color: AppColors.border),
            _buildDetailRow(
              Icons.access_time_outlined,
              'Time',
              formatTimeRange12h(startTime, endTime),
            ),
            const Divider(height: 20, color: AppColors.border),
            _buildDetailRow(
              Icons.timelapse_outlined,
              'Total Duration',
              '$totalDuration min',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: AppTextStyles.bodySmall),
        ),
        Text(
          value,
          style: AppTextStyles.labelLarge,
        ),
      ],
    );
  }

  Widget _buildServicesCard(List<dynamic> services) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Services', style: AppTextStyles.labelLarge),
            const SizedBox(height: 14),
            ...services.asMap().entries.map((entry) {
              final index = entry.key;
              final service = entry.value as Map<String, dynamic>;
              final name = service['name'] ??
                  service['service_name'] ??
                  service['serviceName'] ??
                  'Service';
              final price = service['price'] ?? 0;

              return Column(
                children: [
                  if (index > 0)
                    const Divider(height: 16, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.spa_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name.toString(),
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\u20B9${_formatPrice(price)}',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStylistCard(Map<String, dynamic> stylist) {
    final name = stylist['name'] ?? stylist['user']?['name'] ?? 'Stylist';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accentLight,
              child: Text(
                name.toString()[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.accentDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assigned Stylist', style: AppTextStyles.caption),
                  const SizedBox(height: 2),
                  Text(name.toString(), style: AppTextStyles.labelLarge),
                ],
              ),
            ),
            const Icon(
              Icons.person_outline,
              color: AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    final subtotal = _booking!['subtotal'] ?? _booking!['total_amount'] ?? _booking!['totalAmount'] ?? 0;
    final totalAmount = _booking!['total_amount'] ?? _booking!['totalAmount'] ?? subtotal;
    final paymentStatus = (_booking!['payment_status'] ?? _booking!['paymentStatus'] ?? 'pending').toString();
    final paymentMode = (_booking!['payment_mode'] ?? _booking!['paymentMode'] ?? '').toString();
    final payments = _booking!['payments'] as List<dynamic>? ?? [];
    final tokenAmount = _booking!['token_amount'] ?? _booking!['tokenAmount'] ?? 0;
    final status = _status;

    Color paymentColor;
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
      case 'completed':
        paymentColor = AppColors.success;
        break;
      case 'failed':
        paymentColor = AppColors.error;
        break;
      default:
        paymentColor = AppColors.accent;
    }

    // Determine payment method display from actual payment records
    String? paymentMethodLabel;
    String? paymentTimestamp;
    if (payments.isNotEmpty) {
      final lastPayment = payments.last as Map<String, dynamic>;
      final orderId = (lastPayment['razorpay_order_id'] ?? '').toString();
      if (orderId.startsWith('pay_at_salon')) {
        paymentMethodLabel = 'Cash Payment at Salon';
      } else {
        paymentMethodLabel = 'Paid Online';
      }
      final paidAt = lastPayment['created_at'] ?? lastPayment['createdAt'] ?? '';
      if (paidAt.toString().isNotEmpty) {
        paymentTimestamp = _formatDateTime(paidAt.toString());
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment', style: AppTextStyles.labelLarge),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: paymentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _capitalize(paymentStatus),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: paymentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // G.2: Payment method and timestamp
            if (paymentMethodLabel != null) ...[
              Row(
                children: [
                  Icon(
                    paymentMethodLabel.contains('Cash') ? Icons.money : Icons.credit_card,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(paymentMethodLabel, style: AppTextStyles.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                ],
              ),
              if (paymentTimestamp != null) ...[
                const SizedBox(height: 4),
                Text('Paid on $paymentTimestamp', style: AppTextStyles.caption),
              ],
              const Divider(height: 20, color: AppColors.border),
            ],

            // Token payment breakdown
            if (paymentMode == 'token' && tokenAmount is num && (tokenAmount as num) > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Token (paid online)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  Text('\u20B9${_formatPrice(tokenAmount)}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.success)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remaining${paymentStatus.toLowerCase() == 'paid' ? ' (paid)' : ' (pending)'}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    '\u20B9${_formatPrice((totalAmount is num ? totalAmount : double.tryParse(totalAmount.toString()) ?? 0) - (tokenAmount is num ? tokenAmount : 0))}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: paymentStatus.toLowerCase() == 'paid' ? AppColors.success : AppColors.accent,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.border),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  Text('\u20B9${_formatPrice(subtotal)}', style: AppTextStyles.bodyMedium),
                ],
              ),
              const Divider(height: 20, color: AppColors.border),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Amount', style: AppTextStyles.labelLarge),
                Text(
                  '\u20B9${_formatPrice(totalAmount)}',
                  style: AppTextStyles.h4.copyWith(color: AppColors.primary),
                ),
              ],
            ),

            // G.2: Prominent Pay Now button for unpaid completed bookings
            if (paymentStatus.toLowerCase() != 'paid' && status == 'completed') ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navigateToPayment,
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildMessageSalonButton() {
    final salon = _booking?['salon'] as Map<String, dynamic>?;
    final chatRoomId = _booking!['chat_room']['id'].toString();
    final salonName = salon?['name'] ?? 'Salon';

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                roomId: chatRoomId,
                displayName: salonName,
              ),
            ),
          );
        },
        icon: const Icon(Icons.chat_outlined, size: 18),
        label: const Text('Message Salon'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _rebookSameSalon() {
    final salon = _booking?['salon'] as Map<String, dynamic>?;
    final salonId = salon?['id'] ?? salon?['_id'];
    if (salonId != null) {
      Navigator.pushNamed(context, '/salon-detail', arguments: salonId.toString());
    }
  }

  Widget _buildActionButtons(String status, bool hasReview) {
    final showCancel = status == 'pending' || status == 'confirmed';
    final showReview = status == 'completed' && !hasReview;
    final showRebook = status == 'completed' || status == 'cancelled';
    final paymentStatus = (_booking?['payment_status'] ?? 'pending').toString().toLowerCase();
    final showPay = (status == 'pending' || status == 'confirmed' || status == 'in_progress' || status == 'completed') &&
        paymentStatus != 'paid' &&
        paymentStatus != 'token_paid';

    if (!showCancel && !showReview && !showPay && !showRebook) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPay) ...[
              AppButton(
                text: 'Pay Now',
                onPressed: () => _navigateToPayment(),
                icon: Icons.payment,
              ),
              const SizedBox(height: 8),
            ],
            if (showReview)
              AppButton(
                text: 'Write Review',
                onPressed: _navigateToReview,
                icon: Icons.rate_review_outlined,
              ),
            if (showRebook) ...[
              AppButton(
                text: 'Book Again',
                onPressed: _rebookSameSalon,
                icon: Icons.replay,
              ),
              if (showCancel || showReview) const SizedBox(height: 8),
            ],
            if (showCancel)
              AppButton(
                text: 'Cancel Booking',
                onPressed: _isCancelling ? null : _confirmCancellation,
                isLoading: _isCancelling,
                isOutlined: true,
                backgroundColor: AppColors.error,
                textColor: AppColors.error,
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToPayment() {
    final salon = _booking?['salon'] as Map<String, dynamic>?;
    final totalAmount = _booking?['total_amount'] ?? _booking?['totalAmount'] ?? 0;
    final amount = totalAmount is num ? totalAmount.toDouble() : double.tryParse(totalAmount.toString()) ?? 0;

    Navigator.pushNamed(context, '/payment', arguments: {
      'booking_id': widget.bookingId,
      'amount': amount,
      'salon_name': salon?['name'] ?? 'Salon',
      'payment_type': 'full',
    }).then((result) {
      if (result == true) {
        _loadBooking();
        // F.4: After successful payment, prompt for review
        final hasReview = _booking?['has_review'] == true || _booking?['review'] != null;
        if (!hasReview) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showReviewPromptDialog();
          });
        }
      }
    });
  }

  void _showReviewPromptDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.accent, size: 28),
            const SizedBox(width: 8),
            const Text('Rate your experience', style: AppTextStyles.h4),
          ],
        ),
        content: Text(
          'Your feedback helps the salon improve and helps others find great service.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Maybe Later', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToReview();
            },
            child: Text('Write Review', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price is num) {
      return price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2);
    }
    return price.toString();
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
