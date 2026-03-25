import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'snackbar_utils.dart';

class ErrorHandler {
  /// Extracts a user-friendly message from any error.
  static String getMessage(dynamic error) {
    if (error is ApiException) {
      if (error.statusCode == 0) return 'No internet connection';
      if (error.statusCode == 401) return 'Session expired. Please login again.';
      if (error.statusCode == 403) return 'You don\'t have permission for this action.';
      if (error.statusCode == 404) return 'The requested resource was not found.';
      if (error.statusCode == 422) return error.message; // Validation error - show server message
      if (error.statusCode >= 500) return 'Server error. Please try again later.';
      return error.message;
    }
    if (error is FormatException) return 'Invalid response from server.';
    return 'Something went wrong. Please try again.';
  }

  /// Shows an error snackbar with the appropriate message.
  static void showError(BuildContext context, dynamic error) {
    SnackbarUtils.showError(context, getMessage(error));
  }

  /// Logs the error (for future analytics/crashlytics integration).
  static void log(dynamic error, [StackTrace? stackTrace]) {
    debugPrint('[ErrorHandler] $error');
    if (stackTrace != null) debugPrint('$stackTrace');
  }

  /// Convenience: handle an error by both logging and showing to user.
  static void handle(BuildContext context, dynamic error, [StackTrace? stackTrace]) {
    log(error, stackTrace);
    showError(context, error);
  }
}
