import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';
// Import everything EXCEPT supabase_flutter's own AuthState to avoid a naming
// conflict with our local AuthState class defined below.
// ignore: depend_on_referenced_packages
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/supabase/supabase_client.dart';

part 'auth_notifier.g.dart';

// The deep-link scheme used for OAuth callbacks on iOS/Android.
// Must match the CFBundleURLScheme in Info.plist and the intent-filter in
// AndroidManifest.xml, and must be registered in Supabase Dashboard → Auth → URL Config.
const _oauthRedirectUrl = 'io.supabase.flowapp://login-callback/';

enum AuthStatus { idle, loading, success, confirmEmail, magicLinkSent, error }

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

  // ---------------------------------------------------------------------------
  // Email / password sign-up
  // ---------------------------------------------------------------------------

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

      // Try to upsert the profile row. Non-fatal — the database trigger
      // may have already created it, or RLS may block client inserts.
      try {
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'role': role,
        });
      } catch (_) {}

      // Link any pending tenancy invitations the landlord created using
      // this email address before the tenant had an account.
      try {
        await supabase
            .from('tenancies')
            .update({'tenant_id': response.user!.id})
            .eq('invited_email', email)
            .isFilter('tenant_id', null);
      } catch (_) {}

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

  // ---------------------------------------------------------------------------
  // Magic Link (passwordless email OTP)
  // ---------------------------------------------------------------------------

  Future<void> sendMagicLink(String email) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: kIsWeb ? null : _oauthRedirectUrl,
      );
      state = state.copyWith(status: AuthStatus.magicLinkSent);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Email / password sign-in
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // OAuth sign-in (Google, Apple, …)
  //
  // On mobile this opens the system browser; the deep link brings the user
  // back and supabase_flutter exchanges the code automatically.
  // On web the page redirects and back.
  // Navigation after success is handled by the router's refreshListenable —
  // no manual context.go() required here.
  // ---------------------------------------------------------------------------

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await supabase.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : _oauthRedirectUrl,
      );
      // On mobile, signInWithOAuth just launches the browser and returns
      // immediately.  The actual sign-in completes via the deep link; we
      // reset to idle so the screen doesn't stay in a loading state.
      state = state.copyWith(status: AuthStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Post-OAuth role assignment
  //
  // OAuth users skip the sign-up form so they have no role in their JWT
  // metadata.  After they choose a role via the role-picker overlay, call
  // this to persist it in both the JWT (so the router guard passes) and the
  // profiles table.
  // ---------------------------------------------------------------------------

  Future<void> setOAuthRole({
    required String role,
    required String fullName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No signed-in user.');

      // 1. Update the JWT user-metadata so the router redirect sees the role.
      await supabase.auth.updateUser(
        UserAttributes(data: {'role': role, 'full_name': fullName}),
      );

      // 2. Update the profiles table row created by the DB trigger.
      await supabase.from('profiles').update({
        'role': role,
        'full_name': fullName,
      }).eq('id', user.id);

      // 3. Link any pending tenancy invitations matching this email.
      final email = user.email;
      if (email != null && email.isNotEmpty) {
        try {
          await supabase
              .from('tenancies')
              .update({'tenant_id': user.id})
              .eq('invited_email', email)
              .isFilter('tenant_id', null);
        } catch (_) {}
      }

      state = state.copyWith(status: AuthStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendly(e),
      );
    }
  }

  // ---------------------------------------------------------------------------

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
