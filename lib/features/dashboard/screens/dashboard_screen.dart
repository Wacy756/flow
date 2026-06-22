import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_providers.dart';
import '../../onboarding/screens/onboarding_flow.dart';
import '../widgets/upgrade_sheet.dart';
import 'admin_dashboard.dart';
import 'agent_dashboard.dart';
import 'contractor_dashboard.dart';
import 'landlord_dashboard.dart';
import 'tenant_dashboard.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/abode_toast.dart';

/// Entry point for the dashboard — loads the user's profile and routes to
/// the correct role-specific view.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleCheckoutReturn());
    }
  }

  void _handleCheckoutReturn() {
    final params = Uri.base.queryParameters;
    final checkout = params['checkout'];
    if (checkout == null) return;

    if (checkout == 'success') {
      ref.invalidate(currentPlanProvider);
      ref.invalidate(currentProfileProvider);
      showAbodeToast(context, 'Subscription active — welcome to Abode!');
    } else if (checkout == 'cancel') {
      showAbodeToast(context, 'Checkout cancelled.', isError: true);
    }

  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: p.bg,
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

          // New users go through onboarding first
          if (!profile.onboardingCompleted) {
            return OnboardingFlow(
              profile: profile,
              onComplete: () => ref.invalidate(currentProfileProvider),
            );
          }

          if (profile.isAdmin) return const AdminDashboard();

          return switch (profile.role) {
            'landlord' => LandlordDashboard(profile: profile),
            'tenant' => TenantDashboard(profile: profile),
            'contractor' => ContractorDashboard(profile: profile),
            'agent' => const AgentDashboard(),
            _ => const AgentDashboard(),
          };
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Center(
        child: CircularProgressIndicator(color: p.green),
      );
  }
}

// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Center(
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
                      TextStyle(color: p.sub)),
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
}
