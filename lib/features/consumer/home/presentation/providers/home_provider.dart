import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/salon_model.dart';
import '../../data/repositories/salon_repository.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../services/api_service.dart';

class HomeProvider extends ChangeNotifier {
  final SalonRepository _repo = SalonRepository();

  List<SalonModel> _salons = [];
  List<SalonModel> get salons => _salons;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  int _currentPage = 1;

  String _error = '';
  String get error => _error;

  String? _selectedGenderFilter;
  String? get selectedGenderFilter => _selectedGenderFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  Timer? _searchDebounce;

  double _userLat = 23.0225;
  double _userLng = 72.5714;

  void setLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    fetchSalons();
  }

  void setGenderFilter(String? gender) {
    _selectedGenderFilter = gender;
    fetchSalons();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      fetchSalons();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> fetchSalons() async {
    try {
      _isLoading = true;
      _error = '';
      _currentPage = 1;
      _hasMore = true;
      notifyListeners();

      final result = await _repo.getNearbySalonsPaginated(
        lat: _userLat,
        lng: _userLng,
        genderType: _selectedGenderFilter,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        page: 1,
      );

      _salons = result.items;
      _hasMore = result.hasMore;
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load salons';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      _isLoadingMore = true;
      notifyListeners();

      _currentPage++;
      final result = await _repo.getNearbySalonsPaginated(
        lat: _userLat,
        lng: _userLng,
        genderType: _selectedGenderFilter,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        page: _currentPage,
      );

      _salons.addAll(result.items);
      _hasMore = result.hasMore;
      _isLoadingMore = false;
      notifyListeners();
    } catch (_) {
      _currentPage--;
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
