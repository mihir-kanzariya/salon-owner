/// Centralized route name constants for the Saloon app.
///
/// Usage:
/// ```dart
/// Navigator.pushNamed(context, AppRoutes.phone);
/// ```
class AppRoutes {
  AppRoutes._(); // Prevent instantiation

  // Common routes
  static const String splash = '/';
  static const String phone = '/phone';
  static const String otp = '/otp';
  static const String profileSetup = '/profile-setup';
  static const String notifications = '/notifications';
  static const String reviews = '/reviews';

  // Consumer routes
  static const String home = '/home';
  static const String salonDetail = '/salon-detail';
  static const String booking = '/booking';
  static const String bookingSuccess = '/booking-success';
  static const String bookingDetail = '/booking-detail';
  static const String submitReview = '/submit-review';
  static const String favorites = '/favorites';
  static const String search = '/search';
  static const String editProfile = '/edit-profile';

  // Salon owner routes
  static const String salonHome = '/salon-home';
  static const String salonCreate = '/salon/create';
  static const String salonEdit = '/salon/edit';
  static const String salonAddService = '/salon/add-service';
  static const String salonEditService = '/salon/edit-service';
  static const String salonAddStylist = '/salon/add-stylist';
  static const String salonStylistAvailability = '/salon/stylist-availability';
  static const String salonEarnings = '/salon/earnings';
  static const String salonHours = '/salon/hours';
  static const String salonGallery = '/salon/gallery';
  static const String salonAmenities = '/salon/amenities';
  static const String salonChat = '/salon/chat';
  static const String salonWithdraw = '/salon/withdraw';
  static const String salonTransactions = '/salon/transactions';

  // Payment routes
  static const String payment = '/payment';
}
