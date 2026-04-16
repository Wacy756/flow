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

part 'app_router.g.dart';

// ---------------------------------------------------------------------------
// Route names — use these constants instead of raw strings everywhere.
// ---------------------------------------------------------------------------
class AppRoutes {
  static const String landing = '/';
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
  static const String apply = '/apply';
  static const String settings = '/settings';
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.landing,
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final isAuthed = session != null;
      final loc = state.matchedLocation;
      final goingToAuth = loc == AppRoutes.auth;
      final goingToLanding = loc == AppRoutes.landing;
      final goingToApply = loc.startsWith(AppRoutes.apply);

      // Apply pages are public — anyone can visit them
      if (goingToApply) return null;

      // If not authenticated and trying to access dashboard, redirect to auth
      if (!isAuthed && !goingToAuth && !goingToLanding) {
        return AppRoutes.auth;
      }

      // If already authenticated and going to auth/landing, send to dashboard
      if (isAuthed && (goingToAuth || goingToLanding)) {
        return AppRoutes.dashboard;
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
          final role = state.uri.queryParameters['role'];
          final mode = state.uri.queryParameters['mode'] ?? 'signup';
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
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
}
