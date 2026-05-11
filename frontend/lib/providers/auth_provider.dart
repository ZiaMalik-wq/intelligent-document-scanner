import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:doc_scanner/models/user.dart';
import 'package:doc_scanner/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = true;
  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();

  AuthProvider() {
    tryAutoLogin();
  }

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _authService.login(email, password);
      _token = data['access_token'];
      await _storage.write(key: 'token', value: _token);
      
      // Get user details
      final userData = await _authService.getCurrentUser(_token!);
      _user = User.fromJson(userData);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.register(name, email, password);
      // Auto login after registration
      await login(email, password);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> tryAutoLogin() async {
    _token = await _storage.read(key: 'token');
    if (_token != null) {
      try {
        final userData = await _authService.getCurrentUser(_token!);
        _user = User.fromJson(userData);
      } catch (e) {
        _token = null;
        await _storage.delete(key: 'token');
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    await _storage.delete(key: 'token');
    notifyListeners();
  }
}
