import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/utils/time_utils.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String bookingId;
  final String salonName;
  final String date;
  final String time;
  final String stylistName;
  final double totalPrice;
  final int serviceCount;

  const BookingSuccessScreen({
    super.key,
    required this.bookingId,
    required this.salonName,
    required this.date,
    required this.time,
    required this.stylistName,
    required this.totalPrice,
    required this.serviceCount,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _textFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                // Success icon with animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 64,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _textFadeAnimation,
                  child: const Text('Booking Confirmed!', style: AppTextStyles.h2),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your appointment has been booked successfully',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Booking summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(icon: Icons.store_outlined, label: 'Salon', value: widget.salonName),
                      const Divider(height: 24, color: AppColors.border),
                      _SummaryRow(icon: Icons.calendar_today_outlined, label: 'Date', value: _formatDate()),
                      const SizedBox(height: 12),
                      _SummaryRow(icon: Icons.access_time_outlined, label: 'Time', value: formatTime12h(widget.time)),
                      const SizedBox(height: 12),
                      _SummaryRow(icon: Icons.person_outline, label: 'Stylist', value: widget.stylistName),
                      const SizedBox(height: 12),
                      _SummaryRow(icon: Icons.content_cut_outlined, label: 'Services', value: '${widget.serviceCount} service${widget.serviceCount != 1 ? 's' : ''}'),
                      const Divider(height: 24, color: AppColors.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: AppTextStyles.h4),
                          Text(
                            '\u20B9${widget.totalPrice.toStringAsFixed(0)}',
                            style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
                      Navigator.pushNamed(context, '/booking-detail', arguments: widget.bookingId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('View Booking Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addToCalendar,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('Add to Calendar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addToCalendar() {
    try {
      final dt = DateTime.parse(widget.date);
      final timeParts = widget.time.split(':');
      final startDt = DateTime(dt.year, dt.month, dt.day, int.parse(timeParts[0]), int.parse(timeParts[1]));
      final endDt = startDt.add(const Duration(hours: 1)); // Approximate

      final title = Uri.encodeComponent('Salon Appointment - ${widget.salonName}');
      final details = Uri.encodeComponent('Stylist: ${widget.stylistName}\nServices: ${widget.serviceCount} service(s)');
      final startStr = '${startDt.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0]}Z';
      final endStr = '${endDt.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0]}Z';

      final url = 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&details=$details&dates=$startStr/$endStr';
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Calendar error: $e');
    }
  }

  String _formatDate() {
    try {
      final dt = DateTime.parse(widget.date);
      return DateFormat('EEE, d MMM yyyy').format(dt);
    } catch (_) {
      return widget.date;
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: AppTextStyles.labelMedium),
      ],
    );
  }
}
