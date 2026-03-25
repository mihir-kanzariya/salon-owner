import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/loading_widget.dart';
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
      setState(() => _isLoading = false);
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
