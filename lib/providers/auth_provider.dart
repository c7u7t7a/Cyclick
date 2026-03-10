import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// ─── Service Provider ─────────────────────────────────────────────────────────
final authServiceProvider =
    Provider<AuthService>((ref) => AuthService());

// ─── State ────────────────────────────────────────────────────────────────────
class AuthState {
  final UserModel? user;

  const AuthState({this.user});

  bool get isLoggedIn => user != null;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<AuthState>> {
  final AuthService _service;

  AuthNotifier(this._service)
      : super(const AsyncValue.data(AuthState()));

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _service.signIn(email: email, password: password);
      return AuthState(user: user);
    });
  }

  Future<void> signUp(String name, String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user =
          await _service.signUp(name: name, email: email, password: password);
      return AuthState(user: user);
    });
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const AsyncValue.data(AuthState());
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AuthState>>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
