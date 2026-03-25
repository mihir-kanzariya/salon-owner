import '../../../../../config/api_config.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../services/api_service.dart';
import '../models/salon_model.dart';

/// Generic paginated result wrapper.
class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int totalPages;
  final int total;
  bool get hasMore => page < totalPages;

  const PaginatedResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
}

class SalonRepository {
  final ApiService _api = ApiService();

  Future<List<SalonModel>> getNearbySalons({
    required double lat,
    required double lng,
    double radius = 10,
    String? genderType,
    String? search,
    int page = 1,
    int limit = AppConstants.paginationLimit,
  }) async {
    final result = await getNearbySalonsPaginated(
      lat: lat, lng: lng, radius: radius,
      genderType: genderType, search: search,
      page: page, limit: limit,
    );
    return result.items;
  }

  Future<PaginatedResult<SalonModel>> getNearbySalonsPaginated({
    required double lat,
    required double lng,
    double radius = 10,
    String? genderType,
    String? search,
    int page = 1,
    int limit = AppConstants.paginationLimit,
  }) async {
    final params = <String, dynamic>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (genderType != null) params['gender_type'] = genderType;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _api.get(ApiConfig.nearbySalons, queryParams: params, auth: false);
    final list = (response['data'] as List?) ?? [];
    final meta = response['meta'] as Map<String, dynamic>? ?? {};

    return PaginatedResult(
      items: list.map((e) => SalonModel.fromJson(e)).toList(),
      page: meta['page'] ?? page,
      totalPages: meta['totalPages'] ?? 1,
      total: meta['total'] ?? list.length,
    );
  }

  Future<SalonModel> getSalonDetail(String salonId) async {
    final response = await _api.get('${ApiConfig.salonDetail}/$salonId', auth: false);
    return SalonModel.fromJson(response['data']);
  }

  Future<bool> toggleFavorite(String salonId) async {
    final response = await _api.post('${ApiConfig.salonDetail}/$salonId/favorite');
    return response['data']?['is_favorite'] ?? false;
  }

  Future<List<SalonModel>> getFavorites() async {
    final response = await _api.get(ApiConfig.favorites);
    final list = (response['data'] as List?) ?? [];
    return list.map((e) => SalonModel.fromJson(e)).toList();
  }
}
