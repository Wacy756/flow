import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';
import 'contractor_dashboard.dart';
import 'landlord_dashboard.dart';
import 'tenant_dashboard.dart';

/// Entry point for the dashboard — loads the user's profile and routes to
/// the correct role-specific view.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: profileAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(error: e.toString()),
        data: (profile) {
          if (profile == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => context.go(AppRoutes.auth),
            );
            return const _LoadingView();
          }

          return switch (profile.role) {
            'landlord' => LandlordDashboard(profile: profile),
            'tenant' => TenantDashboard(profile: profile),
            'contractor' => ContractorDashboard(profile: profile),
            'agent' => _AgentPlaceholder(profile: profile),
            _ => _AgentPlaceholder(profile: profile),
          };
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Something went wrong',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await supabase.auth.signOut();
                  if (context.mounted) context.go(AppRoutes.landing);
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Agent placeholder (Phase 6+)
// ---------------------------------------------------------------------------

class _AgentPlaceholder extends StatelessWidget {
  final UserProfile profile;
  const _AgentPlaceholder({required this.profile});

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.roleGradient(profile.role);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Flow'),
        actions: [
          TextButton(
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) context.go(AppRoutes.landing);
            },
            child: const Text('Sign Out',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.business_center_outlined,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text('Welcome, ${profile.fullName}!',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  profile.role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Agent dashboard — coming soon.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
