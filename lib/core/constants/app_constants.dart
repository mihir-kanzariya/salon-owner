class AppConstants {
  static const String appName = 'Saloon';
  static const String consumerAppName = 'HeloHair';
  static const String salonAppName = 'HeloHair Business';
  
  static const int otpLength = 4;
  static const int otpExpirySeconds = 300;
  
  static const double defaultLatitude = 23.0225;
  static const double defaultLongitude = 72.5714;
  static const double defaultSearchRadius = 10.0; // km
  
  static const int paginationLimit = 10;
  
  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String appModeKey = 'app_mode'; // 'consumer' or 'salon'
  
  // Booking status
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  static const String statusNoShow = 'no_show';
}
