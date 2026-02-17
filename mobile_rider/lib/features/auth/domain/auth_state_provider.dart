import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/auth_repository.dart';

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref.read(authRepositoryProvider));
});

class AuthState {
  final bool isAuthenticated;
  final String? token;
  final int? userId;
  final bool isLoading;
  final String? error;

  AuthState({
    this.isAuthenticated = false,
    this.token,
    this.userId,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    int? userId,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthStateNotifier(this._repository) : super(AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await _storage.read(key: 'auth_token');
    final userIdStr = await _storage.read(key: 'user_id');

    if (token != null && userIdStr != null) {
      state = state.copyWith(
        isAuthenticated: true,
        token: token,
        userId: int.tryParse(userIdStr),
      );
    }
  }

  Future<void> login(String phone, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.login(phone, password);

    if (result.isSuccess) {
      await _storage.write(key: 'auth_token', value: result.token!);
      await _storage.write(key: 'user_id', value: result.userId.toString());

      state = state.copyWith(
        isAuthenticated: true,
        token: result.token,
        userId: result.userId,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.error,
      );
    }
  }

  Future<void> register(String phone, String password, {String? name}) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.register(
      phone: phone,
      password: password,
      name: name,
    );

    if (result.isSuccess) {
      await _storage.write(key: 'auth_token', value: result.token!);
      await _storage.write(key: 'user_id', value: result.userId.toString());

      state = state.copyWith(
        isAuthenticated: true,
        token: result.token,
        userId: result.userId,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.error,
      );
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_id');

    state = AuthState();
  }
}
