import '../../../../config/api_config.dart';
import '../../../../services/api_service.dart';
import '../../../../core/utils/storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    return await _api.post(ApiConfig.sendOtp, body: {'phone': phone}, auth: false);
  }
  
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final response = await _api.post(
      ApiConfig.verifyOtp,
      body: {'phone': phone, 'otp': otp},
      auth: false,
    );
    
    if (response['success'] == true) {
      final data = response['data'];
      await _storage.saveAccessToken(data['accessToken']);
      await _storage.saveRefreshToken(data['refreshToken']);
      await _storage.saveUser(data['user']);
    }
    
    return response;
  }
  
  Future<UserModel?> getProfile() async {
    try {
      final response = await _api.get(ApiConfig.userProfile);
      if (response['success'] == true && response['data'] != null) {
        final user = UserModel.fromJson(response['data']);
        await _storage.saveUser(response['data']);
        return user;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
  
  Future<UserModel?> updateProfile(Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.userProfile, body: data);
    if (response['success'] == true && response['data'] != null) {
      final user = UserModel.fromJson(response['data']);
      await _storage.saveUser(response['data']);
      return user;
    }
    return null;
  }
  
  Future<bool> isLoggedIn() async {
    final token = await _storage.getAccessToken();
    return token != null;
  }
  
  UserModel? getCachedUser() {
    final data = _storage.getUser();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }
  
  Future<void> logout() async {
    await _storage.clearAll();
  }
}
