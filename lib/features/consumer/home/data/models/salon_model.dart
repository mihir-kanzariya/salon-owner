class SalonModel {
  final String id;
  final String name;
  final String? description;
  final String phone;
  final String address;
  final String? city;
  final double latitude;
  final double longitude;
  final String genderType;
  final String? coverImage;
  final List<String> gallery;
  final List<String> amenities;
  final Map<String, dynamic> operatingHours;
  final Map<String, dynamic> bookingSettings;
  final double ratingAvg;
  final int ratingCount;
  final bool isActive;
  final double? distance;
  final Map<String, dynamic>? owner;
  final List<dynamic>? services;
  final List<dynamic>? members;
  final double? minPrice;
  final double? maxPrice;

  SalonModel({
    required this.id,
    required this.name,
    this.description,
    required this.phone,
    required this.address,
    this.city,
    required this.latitude,
    required this.longitude,
    this.genderType = 'unisex',
    this.coverImage,
    this.gallery = const [],
    this.amenities = const [],
    this.operatingHours = const {},
    this.bookingSettings = const {},
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.isActive = true,
    this.distance,
    this.owner,
    this.services,
    this.members,
    this.minPrice,
    this.maxPrice,
  });
  
  factory SalonModel.fromJson(Map<String, dynamic> json) {
    return SalonModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'],
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0,
      genderType: json['gender_type'] ?? 'unisex',
      coverImage: json['cover_image'],
      gallery: List<String>.from(json['gallery'] ?? []),
      amenities: List<String>.from(json['amenities'] ?? []),
      operatingHours: json['operating_hours'] ?? {},
      bookingSettings: json['booking_settings'] ?? {},
      ratingAvg: double.tryParse(json['rating_avg']?.toString() ?? '0') ?? 0,
      ratingCount: json['rating_count'] ?? 0,
      isActive: json['is_active'] ?? true,
      distance: json['distance'] != null ? double.tryParse(json['distance'].toString()) : null,
      owner: json['owner'],
      services: json['services'],
      members: json['members'],
      minPrice: double.tryParse(json['min_price']?.toString() ?? ''),
      maxPrice: double.tryParse(json['max_price']?.toString() ?? ''),
    );
  }
  
  bool get isCurrentlyOpen {
    final now = DateTime.now();
    final dayName = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'][now.weekday - 1];
    final dayHours = operatingHours[dayName];
    if (dayHours == null || dayHours['is_open'] != true) return false;
    final openTime = dayHours['open'] as String? ?? '09:00';
    final closeTime = dayHours['close'] as String? ?? '21:00';
    final nowMinutes = now.hour * 60 + now.minute;
    final openParts = openTime.split(':');
    final closeParts = closeTime.split(':');
    final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    final closeMinutes = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
    return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
  }
  
  String get distanceText {
    if (distance == null) return '';
    if (distance! < 1) return '${(distance! * 1000).round()}m';
    return '${distance!.toStringAsFixed(1)} km';
  }
}
