import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../services/api_service.dart';
import '../../../../config/api_config.dart';

class ReviewsScreen extends StatefulWidget {
  final String salonId;
  final String? stylistMemberId;

  const ReviewsScreen({super.key, required this.salonId, this.stylistMemberId});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  bool _hasError = false;

  // Pagination state
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _page = 1;
        _hasMore = true;
      });
      final queryParams = <String, dynamic>{
        'page': _page.toString(),
        'limit': '10',
      };
      if (widget.stylistMemberId != null) {
        queryParams['stylist_member_id'] = widget.stylistMemberId!;
      }
      final response = await _api.get(
        '${ApiConfig.reviews}/salon/${widget.salonId}',
        auth: false,
        queryParams: queryParams,
      );
      final meta = response['meta'];
      _reviews = response['data'] ?? [];
      setState(() {
        _isLoading = false;
        if (meta != null) {
          _hasMore = (meta['page'] as num) < (meta['totalPages'] as num);
        } else {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e);
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _showReplySheet(String reviewId) async {
    final controller = TextEditingController();
    bool isSending = false;

    try {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reply to Review', style: AppTextStyles.h4),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Write your reply...',
                      hintStyle: AppTextStyles.caption,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSending
                          ? null
                          : () async {
                              final text = controller.text.trim();
                              if (text.isEmpty) return;
                              setSheetState(() => isSending = true);
                              try {
                                await _api.post(
                                  '${ApiConfig.reviews}/$reviewId/reply',
                                  body: {'reply': text},
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                _load();
                              } catch (e) {
                                setSheetState(() => isSending = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('Send Reply',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    _page++;

    try {
      final queryParams = <String, dynamic>{
        'page': _page.toString(),
        'limit': '10',
      };
      if (widget.stylistMemberId != null) {
        queryParams['stylist_member_id'] = widget.stylistMemberId!;
      }
      final response = await _api.get(
        '${ApiConfig.reviews}/salon/${widget.salonId}',
        auth: false,
        queryParams: queryParams,
      );
      final meta = response['meta'];
      final newReviews = response['data'] ?? [];
      setState(() {
        _reviews.addAll(newReviews);
        if (meta != null) {
          _hasMore = (meta['page'] as num) < (meta['totalPages'] as num);
        } else {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e);
      _page--;
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reviews')),
      body: _isLoading
          ? const SkeletonList(child: ReviewCardSkeleton())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Failed to load reviews', style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _hasError = false);
                          _load();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                )
          : _reviews.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.rate_review_outlined,
                  title: 'No reviews yet',
                  subtitle: 'Be the first to leave a review!',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _reviews.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final review = _reviews[index];
                      final customer = review['customer'];
                      final salonRating = review['salon_rating'] ?? 0;
                      final stylistRating = review['stylist_rating'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primaryLight,
                                    child: Text(
                                      (customer?['name'] ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(customer?['name'] ?? 'Anonymous', style: AppTextStyles.labelLarge),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        i < salonRating ? Icons.star : Icons.star_border,
                                        color: AppColors.ratingStar,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (review['comment'] != null && (review['comment'] as String).isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(review['comment'], style: AppTextStyles.bodyMedium),
                              ],
                              if (stylistRating != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('Stylist: ', style: AppTextStyles.caption),
                                    ...List.generate(
                                      5,
                                      (i) => Icon(
                                        i < stylistRating ? Icons.star : Icons.star_border,
                                        color: AppColors.accent,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (review['reply'] != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.softSurface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Salon Reply', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
                                      const SizedBox(height: 4),
                                      Text(review['reply'], style: AppTextStyles.bodySmall),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: (review['id'] != null && review['id'].toString().isNotEmpty)
                                        ? () => _showReplySheet(review['id'].toString())
                                        : null,
                                    icon: const Icon(Icons.reply, size: 16),
                                    label: const Text('Reply', style: TextStyle(fontWeight: FontWeight.w600)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
