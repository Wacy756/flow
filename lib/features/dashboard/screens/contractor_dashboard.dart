import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/incident.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/contractor_setup_sheet.dart';
import '../widgets/incident_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/submit_quote_dialog.dart';

class ContractorDashboard extends ConsumerStatefulWidget {
  final UserProfile profile;
  const ContractorDashboard({super.key, required this.profile});

  @override
  ConsumerState<ContractorDashboard> createState() =>
      _ContractorDashboardState();
}

class _ContractorDashboardState extends ConsumerState<ContractorDashboard> {
  bool _showAvailable = true;

  @override
  Widget build(BuildContext context) {
    final myJobsAsync = ref.watch(contractorJobsProvider);
    final availableAsync = ref.watch(availableJobsProvider);
    final profileAsync = ref.watch(contractorProfileProvider);
    final userId = supabase.auth.currentUser?.id ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(contractorJobsProvider);
        ref.invalidate(availableJobsProvider);
        ref.invalidate(contractorProfileProvider);
      },
      child: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.surface,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Center(
                    child: Text('F',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Flow',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontSize: 20)),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await supabase.auth.signOut();
                  if (context.mounted) context.go(AppRoutes.landing);
                },
                icon: const Icon(Icons.logout_rounded,
                    size: 16, color: AppTheme.textSecondary),
                label: const Text('Sign Out',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Welcome header
                _WelcomeHeader(profile: widget.profile),
                const SizedBox(height: 24),

                // Setup banner / edit service areas button
                profileAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (cp) {
                    if (cp != null && cp.isSetUp) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: OutlinedButton.icon(
                          onPressed: () => showContractorSetupSheet(
                              context, existing: cp),
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('View / Edit Service Areas'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.contractorColor,
                            side: const BorderSide(
                                color: AppTheme.contractorColor),
                            minimumSize:
                                const Size(double.infinity, 44),
                          ),
                        ),
                      );
                    }
                    return _SetupBanner(
                      hasProfile: cp != null,
                      onSetup: () => showContractorSetupSheet(
                          context, existing: cp),
                    );
                  },
                ),

                // Tab toggle: My Jobs / Available Jobs
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      _Tab(
                        label: 'My Jobs',
                        active: !_showAvailable,
                        onTap: () =>
                            setState(() => _showAvailable = false),
                      ),
                      _Tab(
                        label: 'Available',
                        active: _showAvailable,
                        onTap: () =>
                            setState(() => _showAvailable = true),
                      ),
                    ],
                  ),
                ),

                // Jobs list
                if (_showAvailable)
                  _jobsList(availableAsync, userId, isAvailable: true)
                else
                  _jobsList(myJobsAsync, userId, isAvailable: false),

                const SizedBox(height: 28),

                // Stats
                _statsRow(myJobsAsync),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobsList(
      AsyncValue<List<Incident>> jobsAsync, String userId,
      {required bool isAvailable}) {
    return jobsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => _emptyState('Failed to load jobs',
          icon: Icons.error_outline),
      data: (jobs) {
        final filtered = isAvailable
            ? jobs // all 'approved' unassigned
            : jobs
                .where((j) => j.status != 'completed')
                .toList();

        if (filtered.isEmpty) {
          return _emptyState(
            isAvailable
                ? 'No available jobs right now.'
                : 'No active jobs.',
            icon: isAvailable
                ? Icons.search_outlined
                : Icons.work_outline,
          );
        }

        return Column(
          children: filtered
              .map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IncidentCard(
                      incident: job,
                      role: 'contractor',
                      currentUserId: userId,
                      onAction: (action) =>
                          _handleAction(job.id, job.title, action),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Future<void> _handleAction(
      String incidentId, String title, String action) async {
    if (action == 'submit_quote') {
      await showSubmitQuoteDialog(
        context,
        incidentId: incidentId,
        incidentTitle: title,
      );
    } else if (action == 'contractor_complete') {
      final ok = await ref
          .read(contractorMarkCompleteProvider.notifier)
          .markComplete(incidentId);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark job complete.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _statsRow(AsyncValue<List<Incident>> myJobsAsync) {
    final jobs = myJobsAsync.valueOrNull ?? [];
    final active = jobs.where((j) => j.status != 'completed').length;
    final done = jobs.where((j) => j.status == 'completed').length;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            value: '$active',
            label: 'Active',
            description: 'Jobs in progress',
            color: AppTheme.contractorColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '$done',
            label: 'Completed',
            description: 'Jobs finished',
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String msg, {required IconData icon}) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 10),
            Text(msg,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Welcome header
// ---------------------------------------------------------------------------

class _WelcomeHeader extends StatelessWidget {
  final UserProfile profile;
  const _WelcomeHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.roleGradient(profile.role);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.construction_outlined,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, ${profile.fullName}!',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        profile.role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (profile.email != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          profile.email!,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Setup banner
// ---------------------------------------------------------------------------

class _SetupBanner extends StatelessWidget {
  final bool hasProfile;
  final VoidCallback onSetup;
  const _SetupBanner({required this.hasProfile, required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              color: Color(0xFFF97316), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasProfile
                      ? 'Complete your profile'
                      : 'Set up your service area',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Add your work types and service areas to start receiving jobs.',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFFEA580C)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.contractorColor,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Set Up',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab widget
// ---------------------------------------------------------------------------

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
