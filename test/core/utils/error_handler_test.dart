import 'package:flutter_test/flutter_test.dart';
import 'package:saloon_app/services/api_service.dart';
import 'package:saloon_app/core/utils/error_handler.dart';

void main() {
  group('ErrorHandler.getMessage', () {
    group('ApiException handling', () {
      test('returns no internet message for status code 0', () {
        final error = ApiException(statusCode: 0, message: 'Connection failed');
        expect(ErrorHandler.getMessage(error), 'No internet connection');
      });

      test('returns session expired message for status code 401', () {
        final error = ApiException(statusCode: 401, message: 'Unauthorized');
        expect(
          ErrorHandler.getMessage(error),
          'Session expired. Please login again.',
        );
      });

      test('returns permission denied message for status code 403', () {
        final error = ApiException(statusCode: 403, message: 'Forbidden');
        expect(
          ErrorHandler.getMessage(error),
          "You don't have permission for this action.",
        );
      });

      test('returns not found message for status code 404', () {
        final error = ApiException(statusCode: 404, message: 'Not Found');
        expect(
          ErrorHandler.getMessage(error),
          'The requested resource was not found.',
        );
      });

      test('returns server message for status code 422 (validation error)', () {
        final error = ApiException(
          statusCode: 422,
          message: 'Email is already taken',
        );
        expect(ErrorHandler.getMessage(error), 'Email is already taken');
      });

      test('returns server error message for status code 500', () {
        final error = ApiException(
          statusCode: 500,
          message: 'Internal Server Error',
        );
        expect(
          ErrorHandler.getMessage(error),
          'Server error. Please try again later.',
        );
      });

      test('returns server error message for status code 502', () {
        final error = ApiException(statusCode: 502, message: 'Bad Gateway');
        expect(
          ErrorHandler.getMessage(error),
          'Server error. Please try again later.',
        );
      });

      test('returns server error message for status code 503', () {
        final error = ApiException(
          statusCode: 503,
          message: 'Service Unavailable',
        );
        expect(
          ErrorHandler.getMessage(error),
          'Server error. Please try again later.',
        );
      });

      test('returns custom message for generic status codes', () {
        final error = ApiException(
          statusCode: 429,
          message: 'Too many requests',
        );
        expect(ErrorHandler.getMessage(error), 'Too many requests');
      });

      test('returns custom message for status code 400', () {
        final error = ApiException(
          statusCode: 400,
          message: 'Bad request data',
        );
        expect(ErrorHandler.getMessage(error), 'Bad request data');
      });
    });

    group('Non-ApiException handling', () {
      test('returns invalid response message for FormatException', () {
        final error = const FormatException('Unexpected character');
        expect(
          ErrorHandler.getMessage(error),
          'Invalid response from server.',
        );
      });

      test('returns generic message for a standard Exception', () {
        final error = Exception('Something unexpected');
        expect(
          ErrorHandler.getMessage(error),
          'Something went wrong. Please try again.',
        );
      });

      test('returns generic message for a String error', () {
        const error = 'Some error string';
        expect(
          ErrorHandler.getMessage(error),
          'Something went wrong. Please try again.',
        );
      });

      test('returns generic message for an int error', () {
        expect(
          ErrorHandler.getMessage(42),
          'Something went wrong. Please try again.',
        );
      });

      test('returns generic message for null error', () {
        expect(
          ErrorHandler.getMessage(null),
          'Something went wrong. Please try again.',
        );
      });
    });
  });
}
