import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/flow_logo.dart';
import '../models/incident.dart';
import '../providers/dashboard_providers.dart';
import '../../../core/notifications/push_service.dart';
import '../widgets/contractor_setup_sheet.dart';
import '../widgets/incident_card.dart';
import '../widgets/notification_bell.dart';
import '../widgets/onboarding_card.dart';
import '../widgets/profile_sheet.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final incidentId = PushDeepLink.incidentId;
      if (incidentId != null) {
        PushDeepLink.incidentId = null;
        // Switch to My Jobs tab so the contractor can see the relevant job
        setState(() => _showAvailable = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myJobsAsync = ref.watch(contractorJobsProvider);
    final availableAsync = ref.watch(availableJobsProvider);
    final profileAsync = ref.watch(contractorProfileProvider);
    final userId = supabase.auth.currentUser?.id ?? '';

    return RefreshIndicator(
      color: AppTheme.green,
      onRefresh: () async {
        ref.invalidate(contractorJobsProvider);
        ref.invalidate(availableJobsProvider);
        ref.invalidate(contractorProfileProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.bgPage,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                const FlowLogo(size: 26),
                const SizedBox(width: 10),
                const Text('Flow'),
              ],
            ),
            actions: [
              const NotificationBell(),
              profileAvatarButton(context, widget.profile),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _WelcomeHeader(profile: widget.profile),
                const SizedBox(height: 24),

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
                            foregroundColor: AppTheme.green,
                            side: const BorderSide(
                                color: AppTheme.green, width: 1.5),
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

                // Tab toggle
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.bgPage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.border, width: 0.5),
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

                if (_showAvailable)
                  _jobsList(availableAsync, userId, isAvailable: true)
                else
                  _jobsList(myJobsAsync, userId, isAvailable: false),

                const SizedBox(height: 28),

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
          child: CircularProgressIndicator(color: AppTheme.green),
        ),
      ),
      error: (e, _) => _emptyState('Failed to load jobs',
          icon: Icons.error_outline),
      data: (jobs) {
        final filtered = isAvailable
            ? jobs
            : jobs
                .where((j) => j.status != 'completed')
                .toList();

        if (filtered.isEmpty) {
          return ContractorNoJobsCard(
            isAvailable: isAvailable,
            onSetupProfile: isAvailable
                ? () {
                    final cp = ref
                        .read(contractorProfileProvider)
                        .valueOrNull;
                    showContractorSetupSheet(context, existing: cp);
                  }
                : null,
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
            backgroundColor: AppTheme.darkBg,
          ),
        );
      }
    } else if (action == 'decline') {
      final ok = await ref
          .read(declineJobProvider.notifier)
          .decline(incidentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Job removed from your feed.' : 'Failed to pass on job.'),
            backgroundColor: AppTheme.darkBg,
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
            color: AppTheme.contractorGlow,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '$done',
            label: 'Completed',
            description: 'Jobs finished',
            color: AppTheme.green,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String msg, {required IconData icon}) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 10),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------

class _WelcomeHeader extends ConsumerWidget {
  final UserProfile profile;
  const _WelcomeHeader({required this.profile});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = profile.fullName.isNotEmpty
        ? profile.fullName[0].toUpperCase()
        : '?';
    final cp = ref.watch(contractorProfileProvider).valueOrNull;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.contractorBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.fullName,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Role pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.contractorBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        profile.role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    // Verified badge
                    if (cp?.hasAnyCert == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.greenBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified_rounded,
                                size: 10, color: AppTheme.green),
                            SizedBox(width: 3),
                            Text(
                              'VERIFIED',
                              style: TextStyle(
                                color: AppTheme.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Rating
                    if (cp != null && cp.totalRatings > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 11, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            '${cp.averageRating.toStringAsFixed(1)} (${cp.totalRatings})',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
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
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              color: AppTheme.textMuted, size: 24),
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
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Add your work types and service areas to start receiving jobs.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
            color: active ? AppTheme.bgSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: AppTheme.border, width: 0.5)
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
