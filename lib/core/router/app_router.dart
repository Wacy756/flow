import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/screens/auth_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/marketing/screens/landing_screen.dart';
import '../../features/marketing/screens/landlords_screen.dart';
import '../../features/marketing/screens/tenants_screen.dart';
import '../../features/marketing/screens/contractors_screen.dart';
import '../../features/marketing/screens/agents_screen.dart';
import '../../features/marketing/screens/pricing_screen.dart';
import '../../features/inspect/screens/inspect_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/splash/mobile_welcome_screen.dart';
import '../../features/dashboard/screens/dd_redirect_screen.dart';
import '../supabase/supabase_client.dart';

part 'app_router.g.dart';

// ---------------------------------------------------------------------------
// Route names
// ---------------------------------------------------------------------------
class AppRoutes {
  static const String splash      = '/splash';
  static const String welcome     = '/welcome';
  static const String landing     = '/';
  static const String auth        = '/auth';
  static const String dashboard   = '/dashboard';
  static const String settings    = '/settings';
  static const String landlords   = '/landlords';
  static const String tenants     = '/tenants';
  static const String contractors = '/contractors';
  static const String agents      = '/agents';
  static const String pricing     = '/pricing';
  static const String inspect     = '/inspect/:token';
  static const String ddComplete  = '/dd-complete';
  static const String ddCancel    = '/dd-cancel';
}

// ---------------------------------------------------------------------------
// Page builder helpers
// ---------------------------------------------------------------------------
Page<void> _noTransitionPage(Widget child) =>
    NoTransitionPage<void>(child: child);

Page<void> _fadePage(LocalKey key, Widget child, {Duration duration = const Duration(milliseconds: 250)}) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );

/// Right-to-left slide used for the sign-up flow.
Page<void> _slidePage(LocalKey key, Widget child) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    // Skip the animated app splash on web — a marketing site should paint its
    // content immediately, not play a 2s app-launch animation. The redirect
    // below still routes signed-in users straight to the dashboard.
    initialLocation: kIsWeb ? AppRoutes.landing : AppRoutes.splash,
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final isAuthed = session != null;
      final loc = state.matchedLocation;

      // Splash handles its own auth check and navigates — don't intercept it
      if (loc == AppRoutes.splash) return null;

      const publicRoutes = {
        AppRoutes.landing,
        AppRoutes.welcome,
        AppRoutes.auth,
        AppRoutes.landlords,
        AppRoutes.tenants,
        AppRoutes.contractors,
        AppRoutes.agents,
        AppRoutes.pricing,
        AppRoutes.ddComplete,
        AppRoutes.ddCancel,
      };
      final isPublic = publicRoutes.contains(loc) || loc.startsWith('/inspect/');

      if (!isAuthed && !isPublic) return AppRoutes.auth;
      if (isAuthed && (loc == AppRoutes.auth || loc == AppRoutes.landing || loc == AppRoutes.welcome)) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _noTransitionPage(const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        // 480ms crossfade — long enough for the Hero logo to fly into position
        pageBuilder: (context, state) => _fadePage(
          state.pageKey,
          const MobileWelcomeScreen(),
          duration: const Duration(milliseconds: 480),
        ),
      ),
      GoRoute(
        path: AppRoutes.landing,
        pageBuilder: (context, state) =>
            _noTransitionPage(const LandingScreen()),
      ),
      GoRoute(
        path: AppRoutes.auth,
        pageBuilder: (context, state) {
          final role = state.uri.queryParameters['role'];
          final mode = state.uri.queryParameters['mode'] ?? 'signup';
          final screen = AuthScreen(initialRole: role, initialMode: mode);
          return _slidePage(state.pageKey, screen);
        },
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        pageBuilder: (context, state) =>
            _fadePage(state.pageKey, const DashboardScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) =>
            _noTransitionPage(const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.landlords,
        pageBuilder: (context, state) =>
            _noTransitionPage(const LandlordsScreen()),
      ),
      GoRoute(
        path: AppRoutes.tenants,
        pageBuilder: (context, state) =>
            _noTransitionPage(const TenantsScreen()),
      ),
      GoRoute(
        path: AppRoutes.contractors,
        pageBuilder: (context, state) =>
            _noTransitionPage(const ContractorsScreen()),
      ),
      GoRoute(
        path: AppRoutes.agents,
        pageBuilder: (context, state) =>
            _noTransitionPage(const AgentsScreen()),
      ),
      GoRoute(
        path: AppRoutes.pricing,
        pageBuilder: (context, state) =>
            _noTransitionPage(const PricingScreen()),
      ),
      GoRoute(
        path: AppRoutes.inspect,
        pageBuilder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return _noTransitionPage(InspectScreen(token: token));
        },
      ),
      GoRoute(
        path: AppRoutes.ddComplete,
        pageBuilder: (context, state) {
          final tenancyId = state.uri.queryParameters['tenancy'];
          return _fadePage(
            state.pageKey,
            DdRedirectScreen(success: true, tenancyId: tenancyId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.ddCancel,
        pageBuilder: (context, state) {
          final tenancyId = state.uri.queryParameters['tenancy'];
          return _fadePage(
            state.pageKey,
            DdRedirectScreen(success: false, tenancyId: tenancyId),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
}
