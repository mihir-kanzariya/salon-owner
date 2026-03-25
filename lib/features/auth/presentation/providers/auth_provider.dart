import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../services/api_service.dart';

enum AuthState { initial, loading, otpSent, authenticated, profileIncomplete, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();
  
  AuthState _state = AuthState.initial;
  AuthState get state => _state;
  
  UserModel? _user;
  UserModel? get user => _user;
  
  String _error = '';
  String get error => _error;
  
  String _phone = '';
  String get phone => _phone;

  bool _isNewUser = false;
  bool get isNewUser => _isNewUser;

  bool _isBusy = false;
  
  void _setState(AuthState state) {
    _state = state;
    notifyListeners();
  }
  
  Future<void> checkAuthStatus() async {
    final loggedIn = await _repo.isLoggedIn();
    if (loggedIn) {
      _user = _repo.getCachedUser();
      if (_user != null && _user!.isProfileComplete) {
        _setState(AuthState.authenticated);
      } else if (_user != null) {
        _setState(AuthState.profileIncomplete);
      } else {
        _setState(AuthState.initial);
      }
    } else {
      _setState(AuthState.initial);
    }
  }

  /// Fetch fresh profile from backend and update cache + state.
  Future<void> refreshProfile() async {
    final user = await _repo.getProfile();
    if (user != null) {
      _user = user;
      notifyListeners();
    }
  }
  
  Future<bool> sendOtp(String phone) async {
    if (_isBusy) return false;
    _isBusy = true;
    try {
      _phone = phone;
      _setState(AuthState.loading);
      await _repo.sendOtp(phone);
      _setState(AuthState.otpSent);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _setState(AuthState.error);
      return false;
    } catch (e) {
      _error = 'Failed to send OTP';
      _setState(AuthState.error);
      return false;
    } finally {
      _isBusy = false;
    }
  }
  
  Future<bool> verifyOtp(String otp) async {
    if (_isBusy) return false;
    _isBusy = true;
    try {
      _setState(AuthState.loading);
      final response = await _repo.verifyOtp(_phone, otp);

      if (response['success'] == true) {
        final data = response['data'];
        _user = UserModel.fromJson(data['user']);
        _isNewUser = data['is_new_user'] ?? false;

        if (_user!.isProfileComplete) {
          _setState(AuthState.authenticated);
        } else {
          _setState(AuthState.profileIncomplete);
        }
        return true;
      }

      _error = response['message'] ?? 'Verification failed';
      _setState(AuthState.error);
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      _setState(AuthState.error);
      return false;
    } catch (e) {
      _error = 'Verification failed';
      _setState(AuthState.error);
      return false;
    } finally {
      _isBusy = false;
    }
  }
  
  Future<bool> updateProfile(String name, String? email, String? gender) async {
    try {
      _setState(AuthState.loading);
      final data = <String, dynamic>{'name': name};
      if (email != null && email.isNotEmpty) data['email'] = email;
      if (gender != null) data['gender'] = gender;
      
      final user = await _repo.updateProfile(data);
      if (user != null) {
        _user = user;
        _setState(AuthState.authenticated);
        return true;
      }
      _error = 'Failed to update profile';
      _setState(AuthState.error);
      return false;
    } catch (e) {
      _error = 'Failed to update profile';
      _setState(AuthState.error);
      return false;
    }
  }
  
  Future<void> logout() async {
    await _repo.logout();
    _user = null;
    _setState(AuthState.initial);
  }
  
  void resetError() {
    _error = '';
    if (_state == AuthState.error) {
      _setState(AuthState.initial);
    }
  }
}
