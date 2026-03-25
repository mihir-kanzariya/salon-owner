import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../core/utils/storage_service.dart';
import 'notification_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic errors;
  
  ApiException({required this.statusCode, required this.message, this.errors});
  
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  final _storage = StorageService();
  Completer<bool>? _refreshCompleter;
  
  Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': '1',
    };
    
    if (auth) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }
  
  Uri _buildUri(String path, {Map<String, dynamic>? queryParams}) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())));
    }
    return uri;
  }
  
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    
    // Handle token refresh on 401
    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        throw ApiException(statusCode: 401, message: 'Token refreshed, retry request');
      }
      // Clear auth on refresh failure
      await _storage.clearAll();
      // Navigate to login screen
      Future.microtask(() {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/phone', (_) => false);
      });
    }
    
    throw ApiException(
      statusCode: response.statusCode,
      message: body['message'] ?? 'Something went wrong',
      errors: body['errors'],
    );
  }
  
  Future<bool> _refreshToken() async {
    // If a refresh is already in progress, wait for it
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await http.post(
        _buildUri(ApiConfig.refreshToken),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        await _storage.saveAccessToken(body['data']['accessToken']);
        await _storage.saveRefreshToken(body['data']['refreshToken']);
        _refreshCompleter!.complete(true);
        return true;
      }
      _refreshCompleter!.complete(false);
      return false;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
  
  // GET
  Future<Map<String, dynamic>> get(String path, {
    Map<String, dynamic>? queryParams,
    bool auth = true,
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.get(
          _buildUri(path, queryParams: queryParams),
          headers: await _getHeaders(auth: auth),
        ).timeout(const Duration(seconds: 30));
        return await _handleResponse(response);
      } on ApiException catch (e) {
        if (e.statusCode == 401 && attempt == 0) continue;
        rethrow;
      } on SocketException {
        throw ApiException(statusCode: 0, message: 'No internet connection');
      } on TimeoutException {
        throw ApiException(statusCode: 0, message: 'Request timed out. Please try again.');
      }
    }
    throw ApiException(statusCode: 401, message: 'Session expired');
  }
  
  // POST
  Future<Map<String, dynamic>> post(String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.post(
          _buildUri(path),
          headers: await _getHeaders(auth: auth),
          body: body != null ? jsonEncode(body) : null,
        ).timeout(const Duration(seconds: 30));
        return await _handleResponse(response);
      } on ApiException catch (e) {
        if (e.statusCode == 401 && attempt == 0) continue;
        rethrow;
      } on SocketException {
        throw ApiException(statusCode: 0, message: 'No internet connection');
      } on TimeoutException {
        throw ApiException(statusCode: 0, message: 'Request timed out. Please try again.');
      }
    }
    throw ApiException(statusCode: 401, message: 'Session expired');
  }
  
  // PUT
  Future<Map<String, dynamic>> put(String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.put(
          _buildUri(path),
          headers: await _getHeaders(auth: auth),
          body: body != null ? jsonEncode(body) : null,
        ).timeout(const Duration(seconds: 30));
        return await _handleResponse(response);
      } on ApiException catch (e) {
        if (e.statusCode == 401 && attempt == 0) continue;
        rethrow;
      } on SocketException {
        throw ApiException(statusCode: 0, message: 'No internet connection');
      } on TimeoutException {
        throw ApiException(statusCode: 0, message: 'Request timed out. Please try again.');
      }
    }
    throw ApiException(statusCode: 401, message: 'Session expired');
  }
  
  // DELETE
  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.delete(
          _buildUri(path),
          headers: await _getHeaders(auth: auth),
        ).timeout(const Duration(seconds: 30));
        return await _handleResponse(response);
      } on ApiException catch (e) {
        if (e.statusCode == 401 && attempt == 0) continue;
        rethrow;
      } on SocketException {
        throw ApiException(statusCode: 0, message: 'No internet connection');
      } on TimeoutException {
        throw ApiException(statusCode: 0, message: 'Request timed out. Please try again.');
      }
    }
    throw ApiException(statusCode: 401, message: 'Session expired');
  }
}
