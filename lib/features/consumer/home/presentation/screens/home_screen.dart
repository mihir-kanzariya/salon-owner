import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/salon_card.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../services/notification_service.dart';
import '../providers/home_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<int>? _unreadSub;
  int _unreadCount = 0;
  String _locationText = 'Find salons near you';

  @override
  void initState() {
    super.initState();
    _unreadCount = NotificationService().unreadCount;
    _unreadSub = NotificationService().unreadCountStream.listen((count) {
      if (mounted) setState(() => _unreadCount = count);
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().fetchSalons();
    });
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return; // Use default location
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() {
          _locationText = 'Nearby salons';
        });
        context.read<HomeProvider>().setLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('[Location] Error: $e');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<HomeProvider>().loadMore();
    }
  }

  void _searchCategory(String category) {
    _searchController.text = category;
    context.read<HomeProvider>().setSearchQuery(category);
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saloon', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(_locationText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await Navigator.pushNamed(context, '/notifications');
              NotificationService().fetchUnreadCount();
            },
          ),
        ],
      ),
      body: Consumer<HomeProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () => provider.fetchSalons(),
            child: CustomScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Search bar — scrolls away
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.primary,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => context.read<HomeProvider>().setSearchQuery(value),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search salons, services...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),

                // Gender filter chips — scrolls away
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: provider.selectedGenderFilter == null,
                          onTap: () => provider.setGenderFilter(null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Men',
                          isSelected: provider.selectedGenderFilter == 'men',
                          onTap: () => provider.setGenderFilter('men'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Women',
                          isSelected: provider.selectedGenderFilter == 'women',
                          onTap: () => provider.setGenderFilter('women'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Unisex',
                          isSelected: provider.selectedGenderFilter == 'unisex',
                          onTap: () => provider.setGenderFilter('unisex'),
                        ),
                      ],
                    ),
                  ),
                ),

                // Category browsing section — scrolls away
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Categories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 90,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _CategoryItem(icon: Icons.content_cut, label: 'Haircut', onTap: () => _searchCategory('Haircut')),
                              _CategoryItem(icon: Icons.face, label: 'Facial', onTap: () => _searchCategory('Facial')),
                              _CategoryItem(icon: Icons.spa, label: 'Spa', onTap: () => _searchCategory('Spa')),
                              _CategoryItem(icon: Icons.brush, label: 'Hair Color', onTap: () => _searchCategory('Hair Color')),
                              _CategoryItem(icon: Icons.auto_awesome, label: 'Bridal', onTap: () => _searchCategory('Bridal')),
                              _CategoryItem(icon: Icons.back_hand_outlined, label: 'Nails', onTap: () => _searchCategory('Nails')),
                              _CategoryItem(icon: Icons.self_improvement, label: 'Massage', onTap: () => _searchCategory('Massage')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 4)),

                // Salon list
                if (provider.isLoading)
                  const SliverFillRemaining(
                    child: SkeletonList(child: SalonCardSkeleton()),
                  )
                else if (provider.error.isNotEmpty)
                  SliverFillRemaining(
                    child: EmptyStateWidget(
                      icon: Icons.error_outline,
                      title: 'Something went wrong',
                      subtitle: provider.error,
                      actionText: 'Retry',
                      onAction: () => provider.fetchSalons(),
                    ),
                  )
                else if (provider.salons.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyStateWidget(
                      icon: Icons.store_outlined,
                      title: 'No salons found',
                      subtitle: 'Try changing your filters or search query',
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= provider.salons.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final salon = provider.salons[index];
                        return SalonCard(
                          name: salon.name,
                          address: salon.address,
                          coverImage: salon.coverImage,
                          rating: salon.ratingAvg,
                          ratingCount: salon.ratingCount,
                          distance: salon.distanceText,
                          genderType: salon.genderType,
                          isOpen: salon.isCurrentlyOpen,
                          minPrice: salon.minPrice,
                          maxPrice: salon.maxPrice,
                          onTap: () => Navigator.pushNamed(context, '/salon-detail', arguments: salon.id),
                        );
                      },
                      childCount: provider.salons.length + (provider.hasMore ? 1 : 0),
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CategoryItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
