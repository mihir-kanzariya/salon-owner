class BookingModel {
  final String id;
  final String bookingNumber;
  final String customerId;
  final String salonId;
  final String? stylistMemberId;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final int totalDurationMinutes;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final String paymentMode;
  final String paymentStatus;
  final String status;
  final bool isAutoAssigned;
  final String? customerNotes;
  final List<dynamic>? services;
  final Map<String, dynamic>? salon;
  final Map<String, dynamic>? stylist;
  final Map<String, dynamic>? customer;
  
  BookingModel({
    required this.id,
    required this.bookingNumber,
    required this.customerId,
    required this.salonId,
    this.stylistMemberId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.totalDurationMinutes,
    required this.subtotal,
    this.discountAmount = 0,
    required this.totalAmount,
    this.paymentMode = 'pay_at_salon',
    this.paymentStatus = 'pending',
    required this.status,
    this.isAutoAssigned = false,
    this.customerNotes,
    this.services,
    this.salon,
    this.stylist,
    this.customer,
  });
  
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      bookingNumber: json['booking_number'] ?? '',
      customerId: json['customer_id'] ?? '',
      salonId: json['salon_id'] ?? '',
      stylistMemberId: json['stylist_member_id'],
      bookingDate: json['booking_date'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      totalDurationMinutes: json['total_duration_minutes'] ?? 0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      paymentMode: json['payment_mode'] ?? 'pay_at_salon',
      paymentStatus: json['payment_status'] ?? 'pending',
      status: json['status'] ?? 'pending',
      isAutoAssigned: json['is_auto_assigned'] ?? false,
      customerNotes: json['customer_notes'],
      services: json['services'],
      salon: json['salon'],
      stylist: json['stylist'],
      customer: json['customer'],
    );
  }
  
  String get statusDisplay {
    switch (status) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'in_progress': return 'In Progress';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      case 'no_show': return 'No Show';
      default: return status;
    }
  }
}
