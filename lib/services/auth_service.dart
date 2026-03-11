import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../models/user_model.dart';

/// Exception thrown by [AuthService] for user-facing error messages.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Authentication service backed by Supabase Auth + `profiles` table.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  UserModel? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    // Return a lightweight stub while the full profile is fetched async.
    return UserModel(
      id: user.id,
      name: user.userMetadata?['name'] as String? ?? user.email ?? '',
      email: user.email ?? '',
    );
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Email and password are required.');
    }
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return await _fetchProfile(res.user!.id, res.user!.email!);
    } on AuthException {
      rethrow;
    } on Exception catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('All fields are required.');
    }
    if (password.length < 6) {
      throw const AuthException('Password must be at least 6 characters.');
    }
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      // The `on_auth_user_created` trigger creates the profiles row.
      return await _fetchProfile(res.user!.id, res.user!.email!);
    } on AuthException {
      rethrow;
    } on Exception catch (e) {
      throw AuthException(_friendlyMessage(e));
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Fetches the full profile row and merges it with the auth user.
  Future<UserModel> _fetchProfile(String uid, String email) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (data == null) {
        return UserModel(id: uid, name: _nameFromEmail(email), email: email);
      }
      return UserModel.fromJson({...data, 'email': email});
    } catch (_) {
      // Profile row may not exist yet (e.g., trigger race); return minimal model.
      return UserModel(id: uid, name: _nameFromEmail(email), email: email);
    }
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first;
    return local[0].toUpperCase() + local.substring(1);
  }

  String _friendlyMessage(Exception e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed') || msg.contains('not confirmed')) {
      return 'Please confirm your email address first. Check your inbox for a confirmation link from Supabase.';
    }
    if (msg.contains('email already')) return 'An account with this email already exists.';
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Network error. Check your connection and try again.';
    }
    // Surface the real message so issues are visible
    return e.toString();
  }
}
