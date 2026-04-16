import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/supabase/supabase_client.dart';

part 'auth_notifier.g.dart';

enum AuthStatus { idle, loading, success, confirmEmail, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({this.status = AuthStatus.idle, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() => const AuthState();

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role},
      );

      if (response.user == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Sign up failed. Please try again.',
        );
        return;
      }

      // Try to upsert the profile row. Non-fatal — the database may have a
      // trigger that already created it, or RLS may block client inserts.
      try {
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'role': role,
        });
      } catch (_) {
        // Silently ignored — DB trigger handles profile creation
      }

      // Link any pending tenancy invitations that the landlord created using
      // this email address before the tenant had an account.
      try {
        await supabase
            .from('tenancies')
            .update({'tenant_id': response.user!.id})
            .eq('invited_email', email)
            .isFilter('tenant_id', null);
      } catch (_) {
        // Non-fatal — if the column doesn't exist or RLS blocks, ignore.
      }

      // session is null when Supabase requires email confirmation
      if (response.session == null) {
        state = state.copyWith(status: AuthStatus.confirmEmail);
      } else {
        state = state.copyWith(status: AuthStatus.success);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      state = state.copyWith(status: AuthStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  void reset() => state = const AuthState();

  String _friendly(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('email not confirmed')) {
      return 'Please confirm your email address before signing in.';
    }
    if (raw.contains('user already registered') ||
        raw.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (raw.contains('password should be at least') ||
        raw.contains('weak password')) {
      return 'Password must be at least 6 characters.';
    }
    if (raw.contains('unable to validate email address') ||
        raw.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (raw.contains('rate limit') || raw.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('failed host lookup')) {
      return 'Network error. Please check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
