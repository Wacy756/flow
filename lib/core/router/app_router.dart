import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/screens/auth_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/marketing/screens/landing_screen.dart';
import '../supabase/supabase_client.dart';

part 'app_router.g.dart';

// ---------------------------------------------------------------------------
// Route names — use these constants instead of raw strings everywhere.
// ---------------------------------------------------------------------------
class AppRoutes {
  static const String landing = '/';
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
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
      final goingToAuth = state.matchedLocation == AppRoutes.auth;
      final goingToLanding = state.matchedLocation == AppRoutes.landing;

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
          return AuthScreen(initialRole: role, initialMode: mode);
        },
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
}
