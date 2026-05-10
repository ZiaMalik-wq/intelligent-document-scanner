import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:doc_scanner/core/constants.dart';

class AuthService {
  final String _baseUrl = AppConstants.baseUrl;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            body: {'username': email, 'password': password},
          )
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      debugPrint("Login error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      print("Register Error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    // Some backend endpoints may return 2xx with an empty body (e.g. register).
    // Handle empty responses gracefully to avoid JSON parse errors.
    final raw = response.body == null ? '' : response.body.trim();
    Map<String, dynamic> body = {};
    if (raw.isNotEmpty) {
      try {
        body = jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        // If parsing fails, throw a clearer exception for non-2xx responses,
        // otherwise return an empty map for successful 2xx responses.
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Invalid JSON response from server');
        }
        body = {};
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw Exception(body['detail'] ?? 'An error occurred');
    }
  }
}
