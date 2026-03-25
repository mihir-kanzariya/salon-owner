import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../config/api_config.dart';

class SubmitReviewScreen extends StatefulWidget {
  final String bookingId;
  final String salonId;
  final String? salonName;
  final String? stylistId;

  const SubmitReviewScreen({
    super.key,
    required this.bookingId,
    required this.salonId,
    this.salonName,
    this.stylistId,
  });

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _commentController = TextEditingController();

  int _salonRating = 0;
  int _stylistRating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _salonRating > 0 && !_isSubmitting;

  Future<void> _submitReview() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    try {
      final body = <String, dynamic>{
        'booking_id': widget.bookingId,
        'salon_id': widget.salonId,
        'salon_rating': _salonRating,
        'comment': _commentController.text.trim(),
      };

      if (widget.stylistId != null && _stylistRating > 0) {
        body['stylist_rating'] = _stylistRating;
      }

      await _api.post(ApiConfig.reviews, body: body);

      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Review submitted successfully!');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, e.message);
      setState(() => _isSubmitting = false);
    } catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Failed to submit review. Please try again.');
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildStarRow({
    required String label,
    required int rating,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return GestureDetector(
              onTap: () => onChanged(starIndex),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  starIndex <= rating ? Icons.star : Icons.star_border,
                  color: AppColors.ratingStar,
                  size: 36,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          _ratingLabel(rating),
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Tap to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Write Review'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Salon header
            if (widget.salonName != null) ...[
              Card(
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
                              widget.salonName!,
                              style: AppTextStyles.h4,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'How was your experience?',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Salon rating card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildStarRow(
                  label: 'Rate the Salon',
                  rating: _salonRating,
                  onChanged: (value) => setState(() => _salonRating = value),
                ),
              ),
            ),

            // Stylist rating card (conditional)
            if (widget.stylistId != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildStarRow(
                    label: 'Rate the Stylist',
                    rating: _stylistRating,
                    onChanged: (value) =>
                        setState(() => _stylistRating = value),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Comment card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Feedback', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commentController,
                      maxLines: 5,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Share your experience...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.softSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit button
            AppButton(
              text: 'Submit Review',
              onPressed: _canSubmit ? _submitReview : null,
              isLoading: _isSubmitting,
              icon: Icons.send_rounded,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
