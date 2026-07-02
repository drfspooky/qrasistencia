import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final http.Client _client = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Dynamically resolve base URL depending on platform
  String get baseUrl {
    if (kIsWeb) {
      // For web, connect to local running django
      return 'http://localhost:8000';
    }
    // Connect to Mac's local IP address so physical devices can access the backend
    return 'http://192.168.1.95:8000';
  }

  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<http.Response> get(String path, {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await _client.get(url, headers: headers);
  }

  Future<http.Response> post(String path, Map<String, dynamic> body, {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await _client.post(url, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> put(String path, Map<String, dynamic> body, {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await _client.put(url, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> patch(String path, Map<String, dynamic> body, {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await _client.patch(url, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> delete(String path, {bool requireAuth = true}) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await _client.delete(url, headers: headers);
  }

  // Save tokens and user details
  Future<void> saveAuthData(String accessToken, String refreshToken, Map<String, dynamic> user) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    await _storage.write(key: 'user_profile', value: jsonEncode(user));
  }

  // Clear session data
  Future<void> clearAuthData() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_profile');
  }

  Future<void> updateUserProfile(Map<String, dynamic> user) async {
    await _storage.write(key: 'user_profile', value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final userJson = await _storage.read(key: 'user_profile');
    if (userJson != null) {
      return jsonDecode(userJson) as Map<String, dynamic>;
    }
    return null;
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }
}
