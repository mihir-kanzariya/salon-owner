class ApiConfig {
  // TODO: Revert to localhost for production
  // For mobile testing, use your laptop's WiFi IP
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.6.81:3000/api/v1',
  );

  // Auth
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh-token';

  // User
  static const String userProfile = '/users/me';
  static const String updateFcmToken = '/users/me/fcm-token';

  // Salon
  static const String nearbySalons = '/salons/nearby';
  static const String salonDetail = '/salons'; // /:id
  static const String mySalons = '/salons/user/my-salons';
  static const String favorites = '/salons/user/favorites';
  static const String createSalon = '/salons';

  // Services
  static const String services = '/services';
  static const String serviceCategories = '/services/categories';

  // Stylists
  static const String stylists = '/stylists';

  // Bookings
  static const String bookings = '/bookings';
  static const String myBookings = '/bookings/my';

  // Payments
  static const String createPaymentOrder = '/payments/create-order';
  static const String verifyPayment = '/payments/verify';

  // Onboarding (Razorpay Route)
  static String linkedAccount(String salonId) => '/salons/$salonId/onboarding/linked-account';
  static String refreshKycStatus(String salonId) => '/salons/$salonId/onboarding/linked-account/refresh';

  // Settlement
  static String salonEarnings(String salonId) => '/payments/salon/$salonId/earnings';
  static String salonWithdrawals(String salonId) => '/payments/salon/$salonId/withdrawals';
  static String requestWithdrawal(String salonId) => '/payments/salon/$salonId/withdraw';

  // Reviews
  static const String reviews = '/reviews';

  // Chat
  static const String chatRooms = '/chat/rooms';

  // Notifications
  static const String notifications = '/notifications';
  static const String unreadCount = '/notifications/unread-count';

  // Uploads
  static const String presignedUrl = '/uploads/presigned-url';

  /// Convert any stored image URL (direct Wasabi URL or S3 key) into a
  /// backend-proxied presigned read URL.
  /// Returns null if the input is null or empty.
  static String? imageUrl(String? urlOrKey) {
    if (urlOrKey == null || urlOrKey.isEmpty) return null;

    // Already a backend proxy URL — return as-is
    if (urlOrKey.contains('/uploads/file/')) return urlOrKey;

    // It's a direct Wasabi URL — extract the key
    // e.g. https://s3.us-east-1.wasabisys.com/bucket/folder/file.jpg
    // or   https://bucket.s3.region.wasabisys.com/folder/file.jpg
    String key = urlOrKey;
    if (urlOrKey.startsWith('http')) {
      final uri = Uri.tryParse(urlOrKey);
      if (uri != null) {
        // Path-style: /bucket/folder/file.jpg → skip first segment if it matches a bucket name
        final segments = uri.pathSegments;
        // Heuristic: if host contains wasabisys.com, extract key from path
        if (uri.host.contains('wasabisys.com')) {
          // Path-style: first segment might be bucket name
          if (segments.length > 1) {
            key = segments.sublist(1).join('/');
          } else {
            key = segments.join('/');
          }
        } else {
          // Some other URL — use as-is
          return urlOrKey;
        }
      }
    }

    return '$baseUrl/uploads/file/$key';
  }
}
