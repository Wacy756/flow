import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/apply/screens/apply_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/marketing/screens/landing_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../supabase/supabase_client.dart';
import 'go_router_refresh_stream.dart';

part 'app_router.g.dart';

// ---------------------------------------------------------------------------
// Route names — use these constants instead of raw strings everywhere.
// ---------------------------------------------------------------------------
class AppRoutes {
  static const String landing   = '/';
  static const String auth      = '/auth';
  static const String dashboard = '/dashboard';
  static const String apply     = '/apply';
  static const String settings  = '/settings';
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------
@riverpod
GoRouter appRouter(Ref ref) {
  // Converts Supabase auth-state changes into a Listenable so go_router
  // re-evaluates its redirect callback on every sign-in / sign-out.
  final refreshStream =
      GoRouterRefreshStream(supabase.auth.onAuthStateChange);

  final router = GoRouter(
    initialLocation: AppRoutes.landing,
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final session  = supabase.auth.currentSession;
      final isAuthed = session != null;
      final loc          = state.matchedLocation;
      final goingToAuth    = loc == AppRoutes.auth;
      final goingToLanding = loc == AppRoutes.landing;
      final goingToApply   = loc.startsWith(AppRoutes.apply);

      // Apply pages are public — anyone can visit them.
      if (goingToApply) return null;

      if (isAuthed) {
        // -------------------------------------------------------------------
        // OAuth users who haven't yet selected a role must stay on /auth so
        // the role-picker overlay can be shown.  We detect them by checking
        // that (a) their provider is not 'email' and (b) they have no 'role'
        // in their JWT user-metadata (set by signUp / updateUser).
        // -------------------------------------------------------------------
        final provider = session.user.appMetadata['provider'] as String?;
        final role     = session.user.userMetadata?['role'] as String?;
        final needsRole =
            provider != null && provider != 'email' && (role == null || role.isEmpty);

        if (needsRole) {
          // Keep them on /auth so the role-picker overlay shows.
          return goingToAuth ? null : AppRoutes.auth;
        }

        // Authenticated with a role — send to dashboard if on auth/landing.
        if (goingToAuth || goingToLanding) return AppRoutes.dashboard;
      } else {
        // Not authenticated — guard protected routes.
        if (!goingToAuth && !goingToLanding) return AppRoutes.auth;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.landing,
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) {
          final role     = state.uri.queryParameters['role'];
          final mode     = state.uri.queryParameters['mode'] ?? 'signup';
          final redirect = state.uri.queryParameters['redirect'];
          return AuthScreen(
              initialRole: role, initialMode: mode, redirect: redirect);
        },
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.apply}/:token',
        builder: (context, state) {
          final token = state.pathParameters['token']!;
          return ApplyScreen(token: token);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );

  // Dispose the refresh stream when the router provider is torn down.
  ref.onDispose(() {
    refreshStream.dispose();
    router.dispose();
  });

  return router;
}
