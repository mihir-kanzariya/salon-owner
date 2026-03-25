import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/salon_card.dart';
import '../../../../../services/api_service.dart';
import '../../../../../config/api_config.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  bool _hasSearched = false;
  List<String> _recentSearches = [];
  int _totalResults = 0;

  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecent = 8;

  static const List<String> _popularCategories = [
    'Haircut',
    'Facial',
    'Hair Color',
    'Spa',
    'Bridal Makeup',
    'Beard Trim',
    'Manicure',
    'Pedicure',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > _maxRecent) {
      _recentSearches = _recentSearches.sublist(0, _maxRecent);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    setState(() => _recentSearches = []);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query == _query) return;

    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _query = query;
      _isLoading = true;
    });

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final response = await _api.get(
        ApiConfig.nearbySalons,
        queryParams: {'search': query},
        auth: false,
      );
      final data = response['data'] as List<dynamic>? ?? [];
      final meta = response['meta'] as Map<String, dynamic>? ?? {};

      if (mounted && _query == query) {
        _saveRecentSearch(query);
        setState(() {
          _results = data.cast<Map<String, dynamic>>();
          _totalResults = meta['total'] ?? data.length;
          _isLoading = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted && _query == query) {
        setState(() {
          _results = [];
          _totalResults = 0;
          _isLoading = false;
          _hasSearched = true;
        });
      }
    }
  }

  void _onCategoryTap(String category) {
    _searchController.text = category;
    // Listener will trigger the search automatically
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: true,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search salons, services...',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.textMuted),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show loading while searching
    if (_isLoading) {
      return const SkeletonList(child: SalonCardSkeleton());
    }

    // Show categories + recent searches when query is empty
    if (_query.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_recentSearches.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Searches', style: AppTextStyles.h4),
                  GestureDetector(
                    onTap: _clearRecentSearches,
                    child: Text(
                      'Clear All',
                      style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentSearches.map((q) => GestureDetector(
                  onTap: () => _searchController.text = q,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.softSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(q, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
            ],
            _buildCategoriesView(),
          ],
        ),
      );
    }

    // Show empty results
    if (_hasSearched && _results.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.search_off,
        title: 'No salons found for \'$_query\'',
        subtitle: 'Try a different search term',
      );
    }

    // Show search results with count
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '$_totalResults result${_totalResults != 1 ? 's' : ''} for "$_query"',
              style: AppTextStyles.caption,
            ),
          );
        }
        final salon = _results[index - 1];
        final salonId = salon['id'] ?? '';
        final distance = salon['distance'] != null
            ? double.tryParse(salon['distance'].toString())
            : null;

        String distanceText = '';
        if (distance != null) {
          if (distance < 1) {
            distanceText = '${(distance * 1000).round()}m';
          } else {
            distanceText = '${distance.toStringAsFixed(1)} km';
          }
        }

        return SalonCard(
          name: salon['name'] ?? '',
          address: salon['address'] ?? '',
          coverImage: salon['cover_image'],
          rating: double.tryParse(salon['rating_avg']?.toString() ?? '0') ?? 0,
          ratingCount: salon['rating_count'] ?? 0,
          distance: distanceText.isNotEmpty ? distanceText : null,
          genderType: salon['gender_type'] ?? 'unisex',
          isOpen: true,
          onTap: () => Navigator.pushNamed(context, '/salon-detail', arguments: salonId),
        );
      },
    );
  }

  Widget _buildCategoriesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Popular Searches', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularCategories.map((term) => ActionChip(
                label: Text(term),
                onPressed: () {
                  _searchController.text = term;
                  _performSearch(term);
                },
                backgroundColor: AppColors.softSurface,
                side: BorderSide.none,
              ))
              .toList(),
        ),
      ],
    );
  }
}
