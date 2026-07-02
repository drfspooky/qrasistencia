import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient = ApiClient();

  AuthNotifier() : super(AuthState()) {
    checkCurrentSession();
  }

  ApiClient get apiClient => _apiClient;

  Future<void> checkCurrentSession() async {
    state = state.copyWith(isLoading: true);
    try {
      print("[AuthNotifier] Starting checkCurrentSession...");
      final token = await _apiClient.getAccessToken();
      print("[AuthNotifier] Token read completed: $token");
      final user = await _apiClient.getUserProfile();
      print("[AuthNotifier] User profile read completed: $user");
      if (token != null && user != null) {
        state = AuthState(isAuthenticated: true, user: user);
      } else {
        state = AuthState(isAuthenticated: false);
      }
      print("[AuthNotifier] checkCurrentSession completed successfully.");
    } catch (e, stackTrace) {
      print("[AuthNotifier] Error in checkCurrentSession: $e");
      print(stackTrace);
      state = AuthState(isAuthenticated: false, errorMessage: e.toString());
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post('/api/v1/auth/login/', {
        'email': email,
        'password': password,
      }, requireAuth: false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access'];
        final refreshToken = data['refresh'];
        final userData = data['user'];

        await _apiClient.saveAuthData(accessToken, refreshToken, userData);
        state = AuthState(isAuthenticated: true, user: userData);
        return true;
      } else {
        final data = jsonDecode(response.body);
        final detail = data['detail'] ?? 'Error de autenticación';
        state = AuthState(isAuthenticated: false, errorMessage: detail);
        return false;
      }
    } catch (e) {
      state = AuthState(isAuthenticated: false, errorMessage: 'Error de red. Verifique conexión.');
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _apiClient.clearAuthData();
    state = AuthState(isAuthenticated: false);
  }

  Future<void> updateUserData(Map<String, dynamic> updatedFields) async {
    if (state.user == null) return;
    final newUser = Map<String, dynamic>.from(state.user!)..addAll(updatedFields);
    await _apiClient.updateUserProfile(newUser);
    state = state.copyWith(user: newUser);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
