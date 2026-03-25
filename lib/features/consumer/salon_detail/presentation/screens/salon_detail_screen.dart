import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../config/api_config.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/skeletons/shimmer_image.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../core/utils/service_icon_helper.dart';
import '../../../../../services/api_service.dart';
import '../../../../consumer/home/data/models/salon_model.dart';
import '../../../../consumer/home/data/repositories/salon_repository.dart';

class SalonDetailScreen extends StatefulWidget {
  final String salonId;

  const SalonDetailScreen({super.key, required this.salonId});

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen>
    with SingleTickerProviderStateMixin {
  final SalonRepository _repo = SalonRepository();
  SalonModel? _salon;
  bool _isLoading = true;
  String _error = '';
  final List<String> _selectedServiceIds = [];

  late TabController _tabController;
  List<dynamic> _reviews = [];
  bool _isLoadingReviews = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSalon();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSalon() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      _salon = await _repo.getSalonDetail(widget.salonId);
      setState(() {
        _isLoading = false;
      });
      _loadReviews();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load salon';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    if (_salon == null) return;
    setState(() {
      _isLoadingReviews = true;
    });
    try {
      final api = ApiService();
      final response = await api.get(
        '/reviews/salon/${_salon!.id}',
      );
      setState(() {
        _reviews = (response['data'] as List?) ?? [];
        _isLoadingReviews = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  void _toggleService(String serviceId) {
    setState(() {
      if (_selectedServiceIds.contains(serviceId)) {
        _selectedServiceIds.remove(serviceId);
      } else {
        _selectedServiceIds.add(serviceId);
      }
    });
  }

  double get _totalPrice {
    if (_salon?.services == null) return 0;
    double total = 0;
    for (final s in _salon!.services!) {
      if (_selectedServiceIds.contains(s['id'])) {
        total += double.tryParse(
                (s['discounted_price'] ?? s['price']).toString()) ??
            0;
      }
    }
    return total;
  }

  int get _totalDuration {
    if (_salon?.services == null) return 0;
    int total = 0;
    for (final s in _salon!.services!) {
      if (_selectedServiceIds.contains(s['id'])) {
        total += (s['duration_minutes'] as int?) ?? 0;
      }
    }
    return total;
  }

  void _shareSalon(SalonModel salon) {
    final text = StringBuffer();
    text.write('Check out ${salon.name}');
    if (salon.address.isNotEmpty) text.write(' at ${salon.address}');
    if (salon.ratingAvg > 0) {
      text.write(' - ${salon.ratingAvg.toStringAsFixed(1)} stars');
    }
    text.write('\n\nBook now on Saloon app!');
    text.write('\nhttps://saloon.app/salon/${salon.id}');
    Share.share(text.toString());
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.h4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: SalonDetailSkeleton());
    // D.3: Enhanced error state with retry button
    if (_error.isNotEmpty || _salon == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Salon')),
        body: EmptyStateWidget(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          subtitle: _error.isNotEmpty ? _error : 'Salon not found',
          actionText: 'Retry',
          onAction: _loadSalon,
        ),
      );
    }

    final salon = _salon!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Cover image SliverAppBar
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppColors.primary,
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: AppColors.white),
                  onPressed: () => _shareSalon(salon),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: ShimmerImage(
                  imageUrl: salon.coverImage != null
                      ? (ApiConfig.imageUrl(salon.coverImage) ?? salon.coverImage!)
                      : null,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: Container(
                    color: AppColors.softSurface,
                    child: const Icon(Icons.store,
                        size: 64, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),

            // Salon info card
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Open/Closed badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(salon.name, style: AppTextStyles.h3),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: salon.isCurrentlyOpen
                                ? AppColors.successLight
                                : AppColors.errorLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            salon.isCurrentlyOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              color: salon.isCurrentlyOpen
                                  ? AppColors.success
                                  : AppColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(salon.address,
                              style: AppTextStyles.bodySmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Rating + Gender badge
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 18, color: AppColors.ratingStar),
                        const SizedBox(width: 4),
                        Text(
                          salon.ratingAvg > 0
                              ? salon.ratingAvg.toStringAsFixed(1)
                              : 'New',
                          style: AppTextStyles.labelLarge,
                        ),
                        if (salon.ratingCount > 0)
                          Text(' (${salon.ratingCount} reviews)',
                              style: AppTextStyles.caption),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            salon.genderType[0].toUpperCase() +
                                salon.genderType.substring(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Sticky TabBar
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelStyle: AppTextStyles.labelLarge,
                  unselectedLabelStyle: AppTextStyles.labelMedium,
                  tabs: const [
                    Tab(text: 'Services'),
                    Tab(text: 'About'),
                    Tab(text: 'Reviews'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildServicesTab(salon),
            _buildAboutTab(salon),
            _buildReviewsTab(),
          ],
        ),
      ),

      // Bottom booking bar
      bottomNavigationBar: _selectedServiceIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedServiceIds.length} service${_selectedServiceIds.length > 1 ? 's' : ''} | $_totalDuration min',
                          style: AppTextStyles.caption,
                        ),
                        Text(
                          '\u20B9${_totalPrice.toStringAsFixed(0)}',
                          style: AppTextStyles.h3
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppButton(
                        text: 'Book Now',
                        onPressed: () {
                          Navigator.pushNamed(context, '/booking', arguments: {
                            'salon_id': salon.id,
                            'service_ids': _selectedServiceIds,
                            'total_duration': _totalDuration,
                            'total_price': _totalPrice,
                            'salon_name': salon.name,
                            'members': (salon.members ?? [])
                                .where((m) => m['role'] == 'stylist')
                                .toList(),
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // ──────────────────────────────────────────────
  // Services Tab
  // ──────────────────────────────────────────────
  Widget _buildServicesTab(SalonModel salon) {
    if (salon.services == null || salon.services!.isEmpty) {
      return const Center(
        child: Text('No services available', style: AppTextStyles.bodySmall),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: salon.services!.length,
      itemBuilder: (context, index) {
        final service = salon.services![index];
        final serviceId = service['id'] as String;
        final isSelected = _selectedServiceIds.contains(serviceId);
        final price = double.tryParse(
                (service['discounted_price'] ?? service['price']).toString()) ??
            0;
        final originalPrice =
            double.tryParse(service['price'].toString()) ?? 0;
        final hasDiscount =
            service['discounted_price'] != null && price < originalPrice;
        final description = (service['description'] ?? '') as String;
        final durationMinutes = (service['duration_minutes'] as int?) ?? 0;
        final icon = ServiceIconHelper.getIcon(
          service['category']?['name'],
          service['name'] ?? '',
        );

        return GestureDetector(
          onTap: () => _toggleService(serviceId),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(10),
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : AppColors.white,
            ),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleService(serviceId),
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 10),

                // Service icon in tinted square
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),

                // Name + description + duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['name'] ?? '',
                        style: AppTextStyles.labelLarge,
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: AppTextStyles.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        '$durationMinutes min',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Price column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\u20B9${price.toStringAsFixed(0)}',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.primary),
                    ),
                    if (hasDiscount)
                      Text(
                        '\u20B9${originalPrice.toStringAsFixed(0)}',
                        style: AppTextStyles.caption.copyWith(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  // About Tab
  // ──────────────────────────────────────────────
  Widget _buildAboutTab(SalonModel salon) {
    final dayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final dayLabels = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final stylists = (salon.members ?? [])
        .where((m) => m['role'] == 'stylist')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About section
          if (salon.description != null && salon.description!.isNotEmpty) ...[
            _buildSectionHeader(Icons.info_outline, 'About'),
            const SizedBox(height: 8),
            Text(salon.description!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 20),
          ],

          // Operating Hours
          _buildSectionHeader(Icons.schedule_outlined, 'Operating Hours'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: List.generate(dayNames.length, (i) {
                final dayKey = dayNames[i];
                final dayData = salon.operatingHours[dayKey];
                final isOpen =
                    dayData != null && dayData['is_open'] == true;
                final openTime = dayData?['open'] ?? '';
                final closeTime = dayData?['close'] ?? '';

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: i < dayNames.length - 1
                      ? const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        )
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dayLabels[i], style: AppTextStyles.labelLarge),
                      isOpen
                          ? Text(
                              '$openTime - $closeTime',
                              style: AppTextStyles.bodySmall,
                            )
                          : const Text(
                              'Closed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.error,
                              ),
                            ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Amenities
          if (salon.amenities.isNotEmpty) ...[
            _buildSectionHeader(Icons.check_circle_outline, 'Amenities'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: salon.amenities
                  .map(
                    (a) => Chip(
                      label: Text(a, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.softSurface,
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Gallery
          if (salon.gallery.isNotEmpty) ...[
            _buildSectionHeader(Icons.photo_library_outlined, 'Gallery'),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: salon.gallery.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ShimmerImage(
                    imageUrl: ApiConfig.imageUrl(salon.gallery[index]) ?? salon.gallery[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    errorWidget: Container(
                      width: 120,
                      height: 120,
                      color: AppColors.softSurface,
                      child: const Icon(Icons.broken_image,
                          color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Our Stylists
          if (stylists.isNotEmpty) ...[
            _buildSectionHeader(Icons.people_outline, 'Our Stylists'),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stylists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final member = stylists[index];
                  final memberName =
                      member['user']?['name'] ?? member['name'] ?? 'Stylist';
                  final avatar = member['user']?['avatar'] ?? member['avatar'];

                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.softSurface,
                        backgroundImage: avatar != null
                            ? CachedNetworkImageProvider(ApiConfig.imageUrl(avatar) ?? avatar)
                            : null,
                        child: avatar == null
                            ? const Icon(Icons.person,
                                color: AppColors.textMuted)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 70,
                        child: Text(
                          memberName,
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Reviews Tab
  // ──────────────────────────────────────────────
  Widget _buildReviewSummary() {
    if (_reviews.isEmpty || _salon == null) return const SizedBox.shrink();

    final ratingCounts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final review in _reviews) {
      final r = ((review['salon_rating'] ?? review['rating']) as num?)?.toInt() ?? 0;
      if (r >= 1 && r <= 5) ratingCounts[r] = ratingCounts[r]! + 1;
    }
    final total = _reviews.length;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Left: average rating
          Column(
            children: [
              Text(
                _salon!.ratingAvg > 0 ? _salon!.ratingAvg.toStringAsFixed(1) : '0.0',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  i < _salon!.ratingAvg.round() ? Icons.star : Icons.star_border,
                  size: 14,
                  color: AppColors.ratingStar,
                )),
              ),
              const SizedBox(height: 4),
              Text('$total reviews', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(width: 20),
          // Right: bar chart
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = ratingCounts[star] ?? 0;
                final pct = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$star', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppColors.softSurface,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ratingStar),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text('$count', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('No reviews yet', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _reviews.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildReviewSummary();
        final reviewIndex = index - 1;
        final review = _reviews[reviewIndex];
        final rating = ((review['salon_rating'] ?? review['rating']) as num?)?.toInt() ?? 0;
        final reviewerName =
            review['customer']?['name'] ?? review['user']?['name'] ?? review['reviewer_name'] ?? 'Anonymous';
        final comment = review['comment'] ?? '';
        final createdAt = review['created_at'] as String?;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reviewIndex > 0) const Divider(color: AppColors.border),
              // Reviewer name + date
              Row(
                children: [
                  Expanded(
                    child:
                        Text(reviewerName, style: AppTextStyles.labelLarge),
                  ),
                  if (createdAt != null)
                    Text(
                      _relativeDate(createdAt),
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Star rating
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: AppColors.ratingStar,
                  );
                }),
              ),
              const SizedBox(height: 6),

              // Comment
              if (comment.isNotEmpty)
                Text(comment, style: AppTextStyles.bodyMedium),
            ],
          ),
        );
      },
    );
  }

  String _relativeDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
      return '${(diff.inDays / 365).floor()} years ago';
    } catch (_) {
      return '';
    }
  }
}

// ──────────────────────────────────────────────
// Sticky TabBar Delegate
// ──────────────────────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
