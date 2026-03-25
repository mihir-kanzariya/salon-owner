import '../../../../../config/api_config.dart';
import '../../../../../services/api_service.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final ApiService _api = ApiService();
  
  Future<Map<String, dynamic>> createBooking({
    required String salonId,
    required List<String> serviceIds,
    required String bookingDate,
    required String startTime,
    String? stylistMemberId,
    String paymentMode = 'pay_at_salon',
    String? customerNotes,
  }) async {
    return await _api.post(ApiConfig.bookings, body: {
      'salon_id': salonId,
      'service_ids': serviceIds,
      'booking_date': bookingDate,
      'start_time': startTime,
      if (stylistMemberId != null) 'stylist_member_id': stylistMemberId,
      'payment_mode': paymentMode,
      if (customerNotes != null) 'customer_notes': customerNotes,
    });
  }

  /// Pay-first flow: creates booking (awaiting_payment) + Razorpay order in one call.
  /// Returns booking data + payment order details.
  Future<Map<String, dynamic>> payAndBook({
    required String salonId,
    required List<String> serviceIds,
    required String bookingDate,
    required String startTime,
    String? stylistMemberId,
    String? customerNotes,
  }) async {
    return await _api.post('${ApiConfig.bookings}/pay-and-book', body: {
      'salon_id': salonId,
      'service_ids': serviceIds,
      'booking_date': bookingDate,
      'start_time': startTime,
      if (stylistMemberId != null) 'stylist_member_id': stylistMemberId,
      'payment_mode': 'online',
      if (customerNotes != null) 'customer_notes': customerNotes,
    });
  }
  
  Future<List<Map<String, dynamic>>> getAvailableSlots({
    required String salonId,
    required String date,
    required int duration,
    String? stylistMemberId,
  }) async {
    final params = <String, dynamic>{
      'date': date,
      'duration': duration.toString(),
    };
    if (stylistMemberId != null) params['stylist_member_id'] = stylistMemberId;
    
    final response = await _api.get(
      '${ApiConfig.bookings}/salon/$salonId/slots',
      queryParams: params,
      auth: false,
    );
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }
  
  Future<List<BookingModel>> getMyBookings({String? status, int page = 1}) async {
    final params = <String, dynamic>{'page': page.toString()};
    if (status != null) params['status'] = status;
    
    final response = await _api.get(ApiConfig.myBookings, queryParams: params);
    final list = (response['data'] as List?) ?? [];
    return list.map((e) => BookingModel.fromJson(e)).toList();
  }
  
  Future<({List<BookingModel> items, bool hasMore})> getMyBookingsPaginated({
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) params['status'] = status;

    final response = await _api.get(ApiConfig.myBookings, queryParams: params);
    final list = (response['data'] as List?) ?? [];
    final meta = response['meta'] as Map<String, dynamic>? ?? {};
    final int totalPages = (meta['totalPages'] as int?) ?? 1;
    final int currentPage = (meta['page'] as int?) ?? page;

    return (
      items: list.map((e) => BookingModel.fromJson(e)).toList(),
      hasMore: currentPage < totalPages,
    );
  }

  Future<BookingModel> getBookingDetail(String bookingId) async {
    final response = await _api.get('${ApiConfig.bookings}/$bookingId');
    return BookingModel.fromJson(response['data']);
  }
  
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    await _api.post('${ApiConfig.bookings}/$bookingId/cancel', body: {
      if (reason != null) 'reason': reason,
    });
  }
}
