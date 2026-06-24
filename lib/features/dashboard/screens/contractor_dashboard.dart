import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../../../core/widgets/role_sidebar.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/theme/theme_provider.dart';
import '../models/contractor_profile.dart';
import '../models/incident.dart';
import '../providers/contractor_providers.dart';
import '../providers/dashboard_providers.dart';
import '../../../core/constants/cert_requirements.dart';
import '../widgets/cert_upload_sheet.dart';
import '../widgets/contractor_job_card.dart';
import '../widgets/contractor_job_detail_sheet.dart';
import '../widgets/dispute_detail_sheet.dart';
import '../widgets/payout_history_sheet.dart';
import '../widgets/contractor_setup_sheet.dart';
import '../widgets/contractor_tos_sheet.dart';
import '../widgets/job_report_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/cert_renewal_sheet.dart';
import 'contractor_onboarding_screen.dart';
import 'contractor_pending_review_screen.dart';
import 'contractor_rejected_screen.dart';
import 'notification_centre_screen.dart';

// ─── Tab enum ─────────────────────────────────────────────────────────────────
enum _CTab { overview, myJobs, available, visits, profile }

// ─── Root widget ──────────────────────────────────────────────────────────────
class ContractorDashboard extends ConsumerStatefulWidget {
  final UserProfile profile;
  const ContractorDashboard({super.key, required this.profile});

  @override
  ConsumerState<ContractorDashboard> createState() =>
      _ContractorDashboardState();
}

class _ContractorDashboardState extends ConsumerState<ContractorDashboard> {
  AbodePalette get p => AbodePalette.of(context);

  _CTab _tab = _CTab.overview;

  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  @override
  Widget build(BuildContext context) {
    final cpAsync = ref.watch(contractorProfileProvider);
    final cp = cpAsync.valueOrNull;

    // Blocking gates — ordered: setup → vetting → dashboard
    if (cpAsync.hasValue && (cp == null || !cp.isSetUp)) {
      return ContractorOnboardingScreen(
        onComplete: () => ref.invalidate(contractorProfileProvider),
      );
    }
    if (cp != null && cp.isPendingReview) {
      return ContractorPendingReviewScreen(
          profile: widget.profile, cp: cp);
    }
    if (cp != null && cp.isRejected) {
      return ContractorRejectedScreen(
          profile: widget.profile, cp: cp);
    }

    return _isMobile ? _buildMobileLayout() : _buildDesktopLayout();
  }

  Widget _buildDesktopLayout() {    return Material(
      color: p.bg,
      child: Row(children: [
        RoleSidebar<_CTab>(
          profile:     widget.profile,
          accent:      p.amber,
          roleLabel:   'contractor',
          tabs:        _CTab.values,
          activeTab:   _tab,
          onTabChange: (t) => setState(() => _tab = t),
          labelOf:     (t) => switch (t) {
            _CTab.overview  => 'Overview',
            _CTab.myJobs    => 'My Jobs',
            _CTab.available => 'Available',
            _CTab.visits    => 'Visits',
            _CTab.profile   => 'Profile',
          },
          iconOf:      (t) => switch (t) {
            _CTab.overview  => Icons.grid_view_rounded,
            _CTab.myJobs    => Icons.work_outline,
            _CTab.available => Icons.search_outlined,
            _CTab.visits    => Icons.calendar_today_outlined,
            _CTab.profile   => Icons.person_outline_rounded,
          },
          onSignOut:  _signOut,
          onSettings: () => showSettingsSheet(context,
              role: 'contractor', accent: p.amber, onSignOut: _signOut),
        ),
        Expanded(child: _buildContent()),
      ]),
    );
  }

  Widget _buildMobileLayout() {    return Material(
      color: p.surface,
      child: Column(children: [
        SafeArea(bottom: false, child: _MobileHeader(profile: widget.profile, onSignOut: _signOut)),
        Expanded(child: ColoredBox(color: p.bg, child: _buildContent())),
        _MobileBottomNav(
          activeTab:   _tab,
          onTabChange: (t) => setState(() => _tab = t),
        ),
      ]),
    );
  }

  Widget _buildContent() => switch (_tab) {
    _CTab.overview  => _OverviewContent(
        profile:         widget.profile,
        onGoToMyJobs:    () => setState(() => _tab = _CTab.myJobs),
        onGoToAvailable: () => setState(() => _tab = _CTab.available),
      ),
    _CTab.myJobs    => _MyJobsContent(profile: widget.profile),
    _CTab.available => _AvailableContent(profile: widget.profile),
    _CTab.visits    => _VisitsContent(profile: widget.profile),
    _CTab.profile   => _ProfileContent(profile: widget.profile),
  };

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) context.go(AppRoutes.landing);
  }
}

// ─── Sign-out confirmation ────────────────────────────────────────────────────
Future<void> _confirmSignOut(BuildContext context, VoidCallback onSignOut) async {
  await showSignOutDialog(context, onSignOut);
}

// ─── Mobile header ────────────────────────────────────────────────────────────
class _MobileHeader extends ConsumerWidget {
  final UserProfile profile;
  final VoidCallback onSignOut;
  const _MobileHeader({required this.profile, required this.onSignOut});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final unread = ref.watch(unreadNotificationCountProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(children: [
        abodeLogo(),
        const SizedBox(width: 8),
        Text('Abode',
            style: TextStyle(
                color: p.text,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: p.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.amber.withValues(alpha: 0.35)),
          ),
          child: Text('CONTRACTOR',
              style: TextStyle(
                  color: p.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ),
        const Spacer(),
        // Notifications bell
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const NotificationCentreScreen())),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: Icon(Icons.notifications_outlined, color: p.sub, size: 20),
            ),
            if (unread > 0)
              Positioned(
                top: -3, right: -3,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: p.red, shape: BoxShape.circle),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.push(AppRoutes.settings),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.border),
            ),
            child: Icon(Icons.settings_outlined, color: p.sub, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ─── Mobile bottom nav ────────────────────────────────────────────────────────
class _MobileBottomNav extends StatelessWidget {
  final _CTab activeTab;
  final ValueChanged<_CTab> onTabChange;
  const _MobileBottomNav({required this.activeTab, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    const items = [
      (_CTab.overview,  Icons.grid_view_rounded,        'Overview'),
      (_CTab.myJobs,    Icons.work_outline,              'My Jobs'),
      (_CTab.available, Icons.search_outlined,           'Available'),
      (_CTab.visits,    Icons.calendar_today_outlined,   'Visits'),
      (_CTab.profile,   Icons.person_outline_rounded,    'Profile'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: items.map((item) {
              final (tab, icon, label) = item;
              final active = activeTab == tab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTabChange(tab),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? p.amber.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 22,
                            color: active ? p.amber : p.muted),
                        const SizedBox(height: 3),
                        Text(label,
                            style: TextStyle(
                                fontSize: 10,
                                color: active ? p.amber : p.muted,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Overview content ─────────────────────────────────────────────────────────
class _OverviewContent extends ConsumerWidget {
  final UserProfile profile;
  final VoidCallback onGoToMyJobs;
  final VoidCallback onGoToAvailable;

  const _OverviewContent({
    required this.profile,
    required this.onGoToMyJobs,
    required this.onGoToAvailable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p           = AbodePalette.of(context);
    final jobsAsync   = ref.watch(contractorJobsProvider);
    final cpAsync     = ref.watch(contractorProfileProvider);
    final availAsync  = ref.watch(availableJobsProvider);
    final jobs        = jobsAsync.valueOrNull ?? [];
    final cp          = cpAsync.valueOrNull;

    // ── Derived data ──────────────────────────────────────────────────────────
    final active    = jobs.where((j) => j.status != 'completed').length;
    final confirmed = jobs.where((j) => j.status == 'visit_confirmed').length;
    final completed = jobs.where((j) => j.status == 'completed').length;
    final availCount = availAsync.valueOrNull?.length ?? 0;
    final disputed  = jobs.where((j) => j.status == 'disputed').length;

    final now = DateTime.now();
    final doneJobs = jobs.where((j) => j.status == 'completed');
    final totalEarnings = doneJobs.fold(
        0.0, (s, j) => s + (j.contractorPayout ?? j.quoteAmount ?? 0));
    final monthEarnings = doneJobs
        .where((j) => j.createdAt.year == now.year && j.createdAt.month == now.month)
        .fold(0.0, (s, j) => s + (j.contractorPayout ?? j.quoteAmount ?? 0));

    final nextVisit = jobs
        .where((j) => j.status == 'visit_confirmed' && j.confirmedVisitSlot != null)
        .toList()
      ..sort((a, b) {
        final da = a.confirmedVisitSlot!['date'] as String? ?? '';
        final db = b.confirmedVisitSlot!['date'] as String? ?? '';
        return da.compareTo(db);
      });

    final isDesktop = MediaQuery.of(context).size.width >= 700;

    // ── Shared left-column widgets ─────────────────────────────────────────────
    Widget leftColumn(EdgeInsets padding) => SingleChildScrollView(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (cp != null && !cp.hasAnyCert) ...[
          GestureDetector(
            onTap: () => showContractorSetupSheet(context, existing: cp),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: p.amber.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.amber.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: p.amber, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Complete your profile to unlock jobs — add insurance & certifications',
                  style: TextStyle(color: p.amber, fontSize: 12, fontWeight: FontWeight.w600),
                )),
                Icon(Icons.arrow_forward_ios_rounded, color: p.amber, size: 12),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (disputed > 0) ...[
          GestureDetector(
            onTap: () {
              final disputedJob = jobs.firstWhere(
                  (j) => j.status == 'disputed',
                  orElse: () => jobs.first);
              showDisputeDetailSheet(context, incident: disputedJob, role: 'contractor');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: p.red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.red.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.gavel_outlined, color: p.red, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  '$disputed job${disputed == 1 ? '' : 's'} disputed — tap to view details',
                  style: TextStyle(color: p.red, fontSize: 12, fontWeight: FontWeight.w600),
                )),
                Icon(Icons.arrow_forward_ios_rounded, color: p.red, size: 11),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (cp != null && cp.workTypes.isNotEmpty) _CertRequirementsBanner(cp: cp),
        _EarningsHeroCard(
          totalEarnings: totalEarnings,
          monthEarnings: monthEarnings,
          completed: completed,
          cp: cp,
          doneJobs: doneJobs.toList(),
          onViewHistory: () => showPayoutHistorySheet(context, jobs: doneJobs.toList()),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _MiniStat(
            value: '$active', label: 'Active',
            icon: Icons.work_outline, color: p.amber, onTap: onGoToMyJobs,
          )),
          const SizedBox(width: 8),
          Expanded(child: _MiniStat(
            value: '$confirmed', label: 'Visits',
            icon: Icons.calendar_today_outlined, color: p.green, onTap: onGoToMyJobs,
          )),
          const SizedBox(width: 8),
          Expanded(child: _MiniStat(
            value: '$completed', label: 'Done',
            icon: Icons.check_circle_outline, color: p.sub, onTap: onGoToMyJobs,
          )),
          const SizedBox(width: 8),
          Expanded(child: _MiniStat(
            value: cp?.totalRatings == 0 ? '—' : cp?.averageRating.toStringAsFixed(1) ?? '—',
            label: 'Rating',
            icon: Icons.star_outline_rounded,
            color: p.amber,
          )),
        ]),
        const SizedBox(height: 14),
        _QuickActions(
          onGoToMyJobs: onGoToMyJobs,
          onGoToAvailable: onGoToAvailable,
          jobs: jobs,
          context: context,
        ),
        const SizedBox(height: 14),
        if (nextVisit.isNotEmpty) ...[
          _NextVisitCard(job: nextVisit.first),
          const SizedBox(height: 16),
        ],
        if (availCount > 0) ...[
          GestureDetector(
            onTap: onGoToAvailable,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: p.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.amber.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: p.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.search_outlined, color: p.amber, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  '$availCount ${availCount == 1 ? 'job' : 'jobs'} available near you',
                  style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600),
                )),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: p.amber),
              ]),
            ),
          ),
          const SizedBox(height: 16),
        ],
        jobsAsync.maybeWhen(
          data: (allJobs) {
            if (allJobs.isEmpty) return const SizedBox.shrink();
            return Column(children: [
              _JobPipelineBar(jobs: allJobs, onTap: onGoToMyJobs),
              const SizedBox(height: 16),
            ]);
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ]),
    );

    // ── Shared right-column widgets ────────────────────────────────────────────
    Widget rightColumn(EdgeInsets padding) => SingleChildScrollView(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Jobs',
                style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: onGoToMyJobs,
              child: Text('View all',
                  style: TextStyle(color: p.amber, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        jobsAsync.when(
          loading: () => const SizedBox(height: 230, child: ListSkeleton(itemCount: 2)),
          error: (_, __) => _EmptyCard(
            icon: Icons.error_outline,
            message: 'Failed to load jobs',
          ),
          data: (jobs) {
            final recent = jobs.take(3).toList();
            if (recent.isEmpty) {
              return _EmptyCard(
                icon: Icons.work_off_outlined,
                message: 'No jobs yet\nHead to Available to find work',
                actionLabel: 'Browse Available',
                onAction: onGoToAvailable,
              );
            }
            return Column(
              children: recent.map((job) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _JobRow(job: job),
              )).toList(),
            );
          },
        ),
      ]),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 57,
            child: leftColumn(const EdgeInsets.fromLTRB(20, 20, 12, 32)),
          ),
          Container(width: 1, color: p.border),
          Expanded(
            flex: 43,
            child: rightColumn(const EdgeInsets.fromLTRB(20, 20, 20, 32)),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: p.amber,
      onRefresh: () async {
        ref.invalidate(contractorJobsProvider);
        ref.invalidate(availableJobsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (cp != null && !cp.hasAnyCert) ...[
            GestureDetector(
              onTap: () => showContractorSetupSheet(context, existing: cp),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: p.amber.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.amber.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: p.amber, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Complete your profile to unlock jobs — add insurance & certifications',
                    style: TextStyle(color: p.amber, fontSize: 12, fontWeight: FontWeight.w600),
                  )),
                  Icon(Icons.arrow_forward_ios_rounded, color: p.amber, size: 12),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (disputed > 0) ...[
            GestureDetector(
              onTap: () {
                final disputedJob = jobs.firstWhere(
                    (j) => j.status == 'disputed',
                    orElse: () => jobs.first);
                showDisputeDetailSheet(context, incident: disputedJob, role: 'contractor');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: p.red.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.red.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.gavel_outlined, color: p.red, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    '$disputed job${disputed == 1 ? '' : 's'} disputed — tap to view details',
                    style: TextStyle(color: p.red, fontSize: 12, fontWeight: FontWeight.w600),
                  )),
                  Icon(Icons.arrow_forward_ios_rounded, color: p.red, size: 11),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (cp != null && cp.workTypes.isNotEmpty) ...[
            _CertRequirementsBanner(cp: cp),
          ],
          _EarningsHeroCard(
            totalEarnings: totalEarnings,
            monthEarnings: monthEarnings,
            completed: completed,
            cp: cp,
            doneJobs: doneJobs.toList(),
            onViewHistory: () => showPayoutHistorySheet(context, jobs: doneJobs.toList()),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _MiniStat(
              value: '$active', label: 'Active',
              icon: Icons.work_outline, color: p.amber, onTap: onGoToMyJobs,
            )),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat(
              value: '$confirmed', label: 'Visits',
              icon: Icons.calendar_today_outlined, color: p.green, onTap: onGoToMyJobs,
            )),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat(
              value: '$completed', label: 'Done',
              icon: Icons.check_circle_outline, color: p.sub, onTap: onGoToMyJobs,
            )),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat(
              value: cp?.totalRatings == 0 ? '—' : cp?.averageRating.toStringAsFixed(1) ?? '—',
              label: 'Rating',
              icon: Icons.star_outline_rounded,
              color: p.amber,
            )),
          ]),
          const SizedBox(height: 14),
          _QuickActions(
            onGoToMyJobs: onGoToMyJobs,
            onGoToAvailable: onGoToAvailable,
            jobs: jobs,
            context: context,
          ),
          const SizedBox(height: 14),
          if (nextVisit.isNotEmpty) ...[
            _NextVisitCard(job: nextVisit.first),
            const SizedBox(height: 16),
          ],
          if (availCount > 0) ...[
            GestureDetector(
              onTap: onGoToAvailable,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: p.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.amber.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: p.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.search_outlined, color: p.amber, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    '$availCount ${availCount == 1 ? 'job' : 'jobs'} available near you',
                    style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600),
                  )),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: p.amber),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ],
          jobsAsync.maybeWhen(
            data: (allJobs) {
              if (allJobs.isEmpty) return const SizedBox.shrink();
              return Column(children: [
                _JobPipelineBar(jobs: allJobs, onTap: onGoToMyJobs),
                const SizedBox(height: 16),
              ]);
            },
            orElse: () => const SizedBox.shrink(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Jobs',
                  style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: onGoToMyJobs,
                child: Text('View all',
                    style: TextStyle(color: p.amber, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          jobsAsync.when(
            loading: () => const SizedBox(height: 230, child: ListSkeleton(itemCount: 2)),
            error: (_, __) => _EmptyCard(
              icon: Icons.error_outline,
              message: 'Failed to load jobs',
            ),
            data: (jobs) {
              final recent = jobs.take(3).toList();
              if (recent.isEmpty) {
                return _EmptyCard(
                  icon: Icons.work_off_outlined,
                  message: 'No jobs yet\nHead to Available to find work',
                  actionLabel: 'Browse Available',
                  onAction: onGoToAvailable,
                );
              }
              return Column(
                children: recent.map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _JobRow(job: job),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── My Jobs content ──────────────────────────────────────────────────────────
class _MyJobsContent extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _MyJobsContent({required this.profile});

  @override
  ConsumerState<_MyJobsContent> createState() => _MyJobsContentState();
}

class _MyJobsContentState extends ConsumerState<_MyJobsContent> {
  bool _showActive = true;
  Incident? _selectedJob;

  @override
  Widget build(BuildContext context) {
    final p         = AbodePalette.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final jobsAsync = ref.watch(contractorJobsProvider);

    return RefreshIndicator(
      color: p.amber,
      onRefresh: () async => ref.invalidate(contractorJobsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(children: [
            Text('My Jobs',
              style: TextStyle(
                color: p.text, fontSize: 22,
                fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const Spacer(),
            AbodeSegmentedControl(
              left: 'Active',
              right: 'Done',
              showLeft: _showActive,
              onLeft:  () => setState(() => _showActive = true),
              onRight: () => setState(() => _showActive = false),
            ),
          ]),
        ),
        Expanded(child: jobsAsync.when(
          loading: () => const SizedBox(height: 380, child: ListSkeleton(itemCount: 4)),
          error:   (_, __) => Center(child: Text('Failed to load jobs',
            style: TextStyle(color: p.sub, fontSize: 14))),
          data: (jobs) {
            final filtered = _showActive
                ? jobs.where((j) => j.status != 'completed').toList()
                : jobs.where((j) => j.status == 'completed').toList();

            if (filtered.isEmpty) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Icon(Icons.work_off_outlined, color: p.muted, size: 24),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _showActive ? 'No active jobs' : 'No completed jobs yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.sub, fontSize: 14, height: 1.5),
                  ),
                ]),
              ));
            }

            if (isDesktop) {
              // Keep _selectedJob in sync with latest provider data
              if (_selectedJob != null) {
                final updated = filtered.where((j) => j.id == _selectedJob!.id).firstOrNull;
                if (updated != null) _selectedJob = updated;
              } else if (filtered.isNotEmpty) {
                _selectedJob = filtered.first;
              }
              return Row(children: [
                SizedBox(
                  width: 340,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final job = filtered[i];
                      return ContractorJobCard(
                        job: job,
                        isAvailable: false,
                        isSelected: _selectedJob?.id == job.id,
                        onTap: () => setState(() => _selectedJob = job),
                      );
                    },
                  ),
                ),
                Container(width: 1, color: p.border),
                Expanded(
                  child: _selectedJob == null
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.touch_app_outlined, color: p.muted, size: 28),
                          const SizedBox(height: 10),
                          Text('Select a job to view details',
                            style: TextStyle(color: p.muted, fontSize: 14)),
                        ]))
                      : ContractorJobDetailPanel(
                          key: ValueKey(_selectedJob!.id),
                          job: _selectedJob!,
                          isAvailable: false,
                        ),
                ),
              ]);
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => ContractorJobCard(
                job: filtered[i], isAvailable: false),
            );
          },
        )),
      ]),
    );
  }
}

// ─── Available content (ToS gated) ───────────────────────────────────────────
class _AvailableContent extends ConsumerWidget {
  final UserProfile profile;
  const _AvailableContent({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p        = AbodePalette.of(context);
    final jobsAsync = ref.watch(availableJobsProvider);
    final tosAsync  = ref.watch(contractorTermsAcceptedProvider);

    // Gate behind Terms acceptance
    if (tosAsync.valueOrNull == false) {
      return _TosGate();
    }

    return RefreshIndicator(
      color: p.amber,
      onRefresh: () async => ref.invalidate(availableJobsProvider),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Available Jobs',
              style: TextStyle(
                  color: p.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Jobs matching your trade & service area',
              style: TextStyle(color: p.sub, fontSize: 13)),
          const SizedBox(height: 12),
          _AvailableCertWarning(),
          const SizedBox(height: 8),
          jobsAsync.when(
            loading: () => const SizedBox(
              height: 380,
              child: ListSkeleton(itemCount: 4),
            ),
            error: (_, __) => _EmptyCard(
              icon: Icons.error_outline,
              message: 'Failed to load available jobs',
            ),
            data: (jobs) {
              if (jobs.isEmpty) {
                // Distinguish "no service areas configured" from "no jobs in area"
                final cp = ref.read(contractorProfileProvider).valueOrNull;
                final hasServiceAreas =
                    cp?.serviceAreas != null && cp!.serviceAreas.isNotEmpty;
                return _EmptyCard(
                  icon: hasServiceAreas
                      ? Icons.search_off_outlined
                      : Icons.map_outlined,
                  message: hasServiceAreas
                      ? 'No available jobs in your area\nCheck back soon or expand your service areas'
                      : 'No service areas set\nGo to your profile settings to set the postcodes you cover',
                );
              }
              return Column(
                children: jobs
                    .map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ContractorJobCard(
                            job: job,
                            isAvailable: true,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Terms of Service gate ────────────────────────────────────────────────────
class _TosGate extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TosGate> createState() => _TosGateState();
}

class _TosGateState extends ConsumerState<_TosGate> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final p       = AbodePalette.of(context);
    final state   = ref.watch(acceptContractorTermsProvider);
    final loading = state is AsyncLoading;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: p.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.amber.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.gavel_outlined, color: p.amber, size: 30),
          ),
          const SizedBox(height: 20),
          Text('Contractor Terms',
            style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text(
            'Before you can accept jobs on Abode, you must agree to our '
            'Contractor Terms of Service. This covers your responsibilities, '
            'quality standards, dispute process, and the 4% platform fee.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.sub, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => setState(() => _accepted = !_accepted),
              child: Container(
                width: 22, height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: _accepted ? p.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _accepted ? p.amber : p.border, width: 1.5),
                ),
                child: _accepted
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _accepted = !_accepted),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'I have read and agree to the ',
                    style: TextStyle(color: p.sub, fontSize: 13, height: 1.5)),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => showContractorTosSheet(context),
                      child: Text('Abode Contractor Terms of Service',
                        style: TextStyle(
                          color: p.amber, fontSize: 13, fontWeight: FontWeight.w600,
                          height: 1.5, decoration: TextDecoration.underline,
                          decorationColor: p.amber)),
                    ),
                  ),
                  TextSpan(text: ' and understand that Abode is not liable for the quality of my work.',
                    style: TextStyle(color: p.sub, fontSize: 13, height: 1.5)),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: (!_accepted || loading) ? null : () async {
                await ref.read(acceptContractorTermsProvider.notifier).accept();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: p.amber,
                foregroundColor: Colors.white,
                disabledBackgroundColor: p.amber.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Accept & Browse Jobs',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Visits content ───────────────────────────────────────────────────────────
class _VisitsContent extends ConsumerWidget {
  final UserProfile profile;
  const _VisitsContent({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p        = AbodePalette.of(context);
    final jobsAsync = ref.watch(contractorJobsProvider);

    return RefreshIndicator(
      color: p.amber,
      onRefresh: () async => ref.invalidate(contractorJobsProvider),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Visits',
              style: TextStyle(
                  color: p.text, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Jobs awaiting or confirmed for a site visit',
              style: TextStyle(color: p.sub, fontSize: 13)),
          const SizedBox(height: 20),
          jobsAsync.when(
            loading: () => const SizedBox(
              height: 380,
              child: ListSkeleton(itemCount: 3),
            ),
            error: (_, __) => _EmptyCard(
              icon: Icons.error_outline,
              message: 'Failed to load visits',
            ),
            data: (jobs) {
              final visits = jobs
                  .where((j) =>
                      j.status == 'visit_requested' ||
                      j.status == 'visit_confirmed')
                  .toList()
                ..sort((a, b) {
                  final da = a.confirmedVisitSlot?['date'] as String? ?? '';
                  final db = b.confirmedVisitSlot?['date'] as String? ?? '';
                  return da.compareTo(db);
                });

              if (visits.isEmpty) {
                return _EmptyCard(
                  icon: Icons.calendar_today_outlined,
                  message:
                      'No visits scheduled\nWhen you request a visit, it will appear here',
                );
              }

              // Group by date
              final grouped = <String, List<Incident>>{};
              for (final job in visits) {
                final rawDate = job.confirmedVisitSlot?['date'] as String?;
                String key;
                if (rawDate != null) {
                  final dt = DateTime.tryParse(rawDate);
                  key = dt != null
                      ? DateFormat('EEEE, d MMMM').format(dt)
                      : 'Scheduled';
                } else {
                  key = job.status == 'visit_requested'
                      ? 'Awaiting confirmation'
                      : 'Unscheduled';
                }
                grouped.putIfAbsent(key, () => []).add(job);
              }

              return Column(
                children: grouped.entries.expand((entry) => [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.border),
                        ),
                        child: Text(entry.key,
                          style: TextStyle(
                            color: p.sub, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  ...entry.value.map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ContractorJobCard(job: job),
                  )),
                ]).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Profile content ──────────────────────────────────────────────────────────
class _ProfileContent extends ConsumerWidget {
  final UserProfile profile;
  const _ProfileContent({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p       = AbodePalette.of(context);
    final cpAsync = ref.watch(contractorProfileProvider);
    final isDark  = ref.watch(themeModeProvider) == ThemeMode.dark;
    final cp      = cpAsync.valueOrNull;

    final initials = profile.fullName.isNotEmpty
        ? profile.fullName.split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2).join().toUpperCase()
        : '?';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // ── Identity card ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.border),
            boxShadow: p.cardShadow,
          ),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: p.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(initials,
                  style: TextStyle(color: p.amber, fontSize: 20,
                      fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.fullName,
                    style: TextStyle(color: p.text, fontSize: 17,
                        fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (profile.email?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(profile.email!,
                      style: TextStyle(color: p.sub, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  _Badge('CONTRACTOR', p.amber),
                  if (cp?.hasAnyCert == true) ...[
                    const SizedBox(width: 6),
                    _Badge('VERIFIED', p.green, icon: Icons.verified_rounded),
                  ],
                  if (cp?.isApproved == true) ...[
                    const SizedBox(width: 6),
                    _Badge('APPROVED', p.green),
                  ],
                ]),
              ],
            )),
            if (cp != null && cp.totalRatings > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 3),
                    Text(cp.averageRating.toStringAsFixed(1),
                        style: TextStyle(color: p.text, fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ]),
                  Text('${cp.totalRatings} ${cp.totalRatings == 1 ? 'review' : 'reviews'}',
                      style: TextStyle(color: p.muted, fontSize: 11)),
                ],
              ),
          ]),
        ),

        if (cpAsync.isLoading) ...[
          const SizedBox(height: 20),
          const SizedBox(height: 180, child: DashboardSkeleton()),
        ],

        if (!cpAsync.isLoading && cp != null && cp.isSetUp) ...[
          const SizedBox(height: 24),

          // ── My Trade ───────────────────────────────────────────────────
          _Group(
            label: 'MY TRADE',
            children: [
              if (cp.workTypes.isNotEmpty)
                _PRow(
                  icon: Icons.construction_outlined,
                  label: 'Trade Types',
                  subtitle: cp.workTypes.take(3).join(', ') +
                      (cp.workTypes.length > 3 ? ' +${cp.workTypes.length - 3}' : ''),
                  onTap: () => showContractorSetupSheet(context, existing: cp),
                ),
              _PRow(
                icon: Icons.map_outlined,
                label: 'Service Areas',
                subtitle: cp.serviceAreas.isEmpty
                    ? 'Not set'
                    : '${cp.serviceAreas.length} area${cp.serviceAreas.length == 1 ? '' : 's'} covered',
                onTap: () => showContractorSetupSheet(context, existing: cp),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Certifications ────────────────────────────────────────────
          if (cp.hasAnyCert) ...[
            _Group(
              label: 'CERTIFICATIONS',
              children: [
                if (cp.insuranceCertNumber?.isNotEmpty == true)
                  _PRow(
                    icon: Icons.shield_outlined,
                    iconColor: p.green,
                    label: 'Public Liability Insurance',
                    subtitle: cp.insuranceCertNumber!,
                    trailing: cp.insuranceExpiry != null
                        ? _ExpiryChip(date: cp.insuranceExpiry!, p: p)
                        : null,
                  ),
                if (cp.gasSafeNumber?.isNotEmpty == true)
                  _PRow(
                    icon: Icons.local_fire_department_outlined,
                    iconColor: p.amber,
                    label: 'Gas Safe Certificate',
                    subtitle: cp.gasSafeNumber!,
                    trailing: cp.gasSafeExpiry != null
                        ? _ExpiryChip(date: cp.gasSafeExpiry!, p: p)
                        : null,
                  ),
                if (cp.niceicNumber?.isNotEmpty == true)
                  _PRow(
                    icon: Icons.electrical_services_outlined,
                    iconColor: p.blue,
                    label: 'NICEIC / Electrical',
                    subtitle: cp.niceicNumber!,
                    trailing: cp.niceicExpiry != null
                        ? _ExpiryChip(date: cp.niceicExpiry!, p: p)
                        : null,
                  ),
                // Renewal upload always available
                _PRow(
                  icon: Icons.upload_file_outlined,
                  label: 'Upload renewal documents',
                  subtitle: 'Submit updated certs for review',
                  onTap: () => showCertRenewalSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CertExpiryAlerts(cp: cp),
            const SizedBox(height: 8),
          ],

          // ── Bank details ───────────────────────────────────────────────
          if (profile.bankAccountName?.isNotEmpty == true ||
              profile.bankSortCode?.isNotEmpty == true) ...[
            _Group(
              label: 'BANK DETAILS',
              children: [
                if (profile.bankAccountName?.isNotEmpty == true)
                  _PRow(
                    icon: Icons.account_balance_outlined,
                    label: 'Account Name',
                    subtitle: profile.bankAccountName!,
                  ),
                if (profile.bankSortCode?.isNotEmpty == true)
                  _PRow(
                    icon: Icons.numbers_outlined,
                    label: 'Sort Code',
                    subtitle: profile.bankSortCode!,
                  ),
                if (profile.bankAccountNumber?.isNotEmpty == true)
                  _PRow(
                    icon: Icons.credit_card_outlined,
                    label: 'Account Number',
                    subtitle: '••••${profile.bankAccountNumber!.length >= 4 ? profile.bankAccountNumber!.substring(profile.bankAccountNumber!.length - 4) : profile.bankAccountNumber!}',
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ],

        // ── Account (always visible) ────────────────────────────────────
        if (!cpAsync.isLoading) ...[
          const SizedBox(height: 20),
          _Group(
            label: 'ACCOUNT',
            children: [
              _PRow(
                icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                label: 'Dark Mode',
                trailing: Switch.adaptive(
                  value: isDark,
                  activeTrackColor: p.amber,
                  onChanged: (v) => v
                      ? ref.read(themeModeProvider.notifier).setDark()
                      : ref.read(themeModeProvider.notifier).setLight(),
                ),
              ),
              if (cp != null && cp.isSetUp)
                _PRow(
                  icon: Icons.edit_outlined,
                  label: 'Edit Trade & Service Areas',
                  onTap: () => showContractorSetupSheet(context, existing: cp),
                ),
              _PRow(
                icon: Icons.logout_outlined,
                label: 'Sign Out',
                isDestructive: true,
                onTap: () => _confirmSignOut(context, () async {
                  await supabase.auth.signOut();
                }),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}



// ─── Job pipeline bar ─────────────────────────────────────────────────────────
class _JobPipelineBar extends StatelessWidget {
  final List<Incident> jobs;
  final VoidCallback onTap;
  const _JobPipelineBar({required this.jobs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p      = AbodePalette.of(context);
    final stages = [
      ('approved',    'Approved',    p.blue),
      ('quoted',      'Quoted',      p.purple),
      ('in_progress', 'In Progress', p.orange),
      ('completed',   'Done',        p.green),
    ];
    final counts = {
      for (final s in stages)
        s.$1: jobs.where((j) => j.status == s.$1).length,
    };
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
          boxShadow: p.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Job Pipeline',
                    style: TextStyle(
                        color: p.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text('$total total',
                    style: TextStyle(color: p.muted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: stages.map((s) {
                final (status, label, color) = s;
                final count  = counts[status] ?? 0;
                final isLast = s == stages.last;
                return Expanded(
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('$count',
                              style: TextStyle(
                                  color: count > 0 ? color : p.muted,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          Text(label,
                              style: TextStyle(
                                  color: p.sub, fontSize: 10),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Icon(Icons.chevron_right_rounded,
                          color: p.muted, size: 14),
                  ]),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: stages.map((s) {
                  final (status, _, color) = s;
                  final count = counts[status] ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Expanded(
                    flex: count,
                    child: Container(height: 5, color: color),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge(this.label, this.color, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
      ],
      Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6)),
    ]),
  );
}

class _JobRow extends StatelessWidget {
  final Incident job;
  const _JobRow({required this.job});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final statusColor = switch (job.status) {
      'completed'   => p.green,
      'in_progress' => p.amber,
      _             => p.sub,
    };
    final statusLabel = switch (job.status) {
      'completed'   => 'Completed',
      'in_progress' => 'In Progress',
      'open'        => 'Open',
      _             => job.status,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
        boxShadow: p.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: p.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.build_outlined, color: p.amber, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(job.propertyAddress ?? 'No address',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.sub, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(statusLabel,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─── Cert expiry alerts ───────────────────────────────────────────────────────
class _CertExpiryAlerts extends StatelessWidget {
  final ContractorDetails cp;
  const _CertExpiryAlerts({required this.cp});

  @override
  Widget build(BuildContext context) {
    final p   = AbodePalette.of(context);
    final now = DateTime.now();
    final alerts = <(String, DateTime)>[];

    if (cp.insuranceExpiry != null) {
      alerts.add(('Public Liability Insurance', cp.insuranceExpiry!));
    }
    if (cp.gasSafeExpiry != null) {
      alerts.add(('Gas Safe Registration', cp.gasSafeExpiry!));
    }
    if (cp.niceicExpiry != null) {
      alerts.add(('NICEIC Registration', cp.niceicExpiry!));
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    final relevant = alerts
        .where((a) => a.$2.difference(now).inDays <= 60)
        .toList();

    if (relevant.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.amber.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: p.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: p.amber, size: 15),
              ),
              const SizedBox(width: 8),
              Text('Certification Reminders',
                  style: TextStyle(
                      color: p.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ...relevant.map((a) {
              final days    = a.$2.difference(now).inDays;
              final expired = days < 0;
              final color   = expired
                  ? p.red
                  : days <= 14 ? p.red : p.amber;
              final label   = expired
                  ? 'Expired ${(-days)}d ago'
                  : days == 0
                      ? 'Expires today!'
                      : 'Expires in ${days}d';
              return GestureDetector(
                onTap: () => showCertRenewalSheet(context),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.verified_outlined, color: color, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.$1,
                          style: TextStyle(
                              color: p.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                    Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Renew',
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Empty card ───────────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(children: [
        Icon(icon, size: 40, color: p.muted),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: p.sub, fontSize: 14, height: 1.5)),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: p.amber,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(actionLabel!,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }
}

// ─── Mini stat tile (Overview) ────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _MiniStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
          boxShadow: p.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: p.text, fontSize: 22, fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: p.sub, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Next visit card (Overview) ───────────────────────────────────────────────
class _NextVisitCard extends StatelessWidget {
  final Incident job;
  const _NextVisitCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final p    = AbodePalette.of(context);
    final slot = job.confirmedVisitSlot;
    final label = slot?['label'] as String? ?? 'Confirmed visit';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.green.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: p.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.calendar_today_rounded, color: p.green, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next visit: $label',
                style: TextStyle(color: p.green, fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(job.title,
                style: TextStyle(color: p.text, fontSize: 13,
                    fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (job.propertyAddress?.isNotEmpty == true)
              Text(job.propertyAddress!,
                  style: TextStyle(color: p.sub, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: p.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Confirmed',
              style: TextStyle(color: p.green, fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ─── Revolut-style dark earnings hero card ────────────────────────────────────
class _EarningsHeroCard extends StatelessWidget {
  final double totalEarnings;
  final double monthEarnings;
  final int completed;
  final ContractorDetails? cp;
  final List<Incident> doneJobs;
  final VoidCallback onViewHistory;

  const _EarningsHeroCard({
    required this.totalEarnings,
    required this.monthEarnings,
    required this.completed,
    required this.cp,
    required this.doneJobs,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final p   = AbodePalette.of(context);
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    final pendingJobs = doneJobs.where((j) =>
        j.paymentStatus != 'payout_sent' && (j.contractorPayout ?? 0) > 0).toList();
    final pendingTotal = pendingJobs.fold(0.0, (s, j) => s + (j.contractorPayout ?? 0));

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E0F10), Color(0xFF070708)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1C1A10)),
        boxShadow: [BoxShadow(
          color: const Color(0x20F59E0B),
          blurRadius: 32, offset: const Offset(0, 10),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row — label + rating
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: p.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.amber.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                decoration: BoxDecoration(
                  color: p.amber, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: p.amber.withValues(alpha: 0.6), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 5),
              Text('EARNINGS',
                style: TextStyle(color: p.amber, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ]),
          ),
          const Spacer(),
          if (cp != null && cp!.totalRatings > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 12, color: p.amber),
                const SizedBox(width: 3),
                Text(cp!.averageRating.toStringAsFixed(1),
                  style: TextStyle(color: p.amber, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 3),
                Text('(${cp!.totalRatings})',
                  style: const TextStyle(color: Color(0xFF555560), fontSize: 10)),
              ]),
            )
          else
            Text(DateFormat('MMM yyyy').format(DateTime.now()),
              style: const TextStyle(color: Color(0xFF555560), fontSize: 12)),
        ]),
        const SizedBox(height: 14),

        // Big earnings number
        const Text('TOTAL EARNED',
          style: TextStyle(color: Color(0xFF4A4A52), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
        const SizedBox(height: 3),
        Text(
          fmt.format(totalEarnings),
          style: const TextStyle(
            color: Colors.white, fontSize: 48,
            fontWeight: FontWeight.w200, letterSpacing: -2.5, height: 1.0,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text('$completed jobs completed',
          style: const TextStyle(color: Color(0xFF4A4A52), fontSize: 13)),

        // This month + pending
        if (monthEarnings > 0 || pendingTotal > 0) ...[
          const SizedBox(height: 14),
          Row(children: [
            if (monthEarnings > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: p.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.green.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '+${fmt.format(monthEarnings)} this month',
                  style: TextStyle(color: p.green, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            if (monthEarnings > 0 && pendingTotal > 0) const SizedBox(width: 8),
            if (pendingTotal > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: p.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.amber.withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.schedule_rounded, size: 11, color: p.amber),
                  const SizedBox(width: 4),
                  Text('${fmt.format(pendingTotal)} pending',
                    style: TextStyle(color: p.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ],

        // Verified badge row
        if (cp != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            _Badge('CONTRACTOR', p.amber),
            if (cp!.hasAnyCert) ...[
              const SizedBox(width: 6),
              _Badge('VERIFIED', p.green, icon: Icons.verified_rounded),
            ],
            if (cp!.isApproved) ...[
              const SizedBox(width: 6),
              _Badge('APPROVED', p.green),
            ],
          ]),
        ],

        // View history link
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onViewHistory,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('View payout history',
              style: const TextStyle(
                color: Color(0xFF666670), fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF666670)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Quick actions ────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final VoidCallback onGoToMyJobs;
  final VoidCallback onGoToAvailable;
  final List<Incident> jobs;
  final BuildContext context;

  const _QuickActions({
    required this.onGoToMyJobs,
    required this.onGoToAvailable,
    required this.jobs,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final p = AbodePalette.of(ctx);

    // Find in-progress jobs for "Submit Report" quick action
    final inProgress = jobs.where((j) => j.status == 'in_progress').toList();
    final hasInProgress = inProgress.isNotEmpty;

    final actions = <(IconData, String, Color, VoidCallback)>[
      (Icons.search_outlined, 'Find Work', p.amber, onGoToAvailable),
      (Icons.calendar_today_outlined, 'My Visits', p.green, onGoToMyJobs),
      if (hasInProgress)
        (Icons.upload_file_outlined, 'Submit Report', p.amber,
          () => showJobReportSheet(context, job: inProgress.first)),
      (Icons.work_outline, 'All Jobs', p.blue, onGoToMyJobs),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Actions',
        style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
      const SizedBox(height: 10),
      SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: actions.length,
          itemBuilder: (_, i) {
            final (icon, label, color, onTap) = actions[i];
            return GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 7),
                  Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─── Profile group + row (Profile tab) ───────────────────────────────────────
class _Group extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _Group({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label,
              style: TextStyle(color: p.muted, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.7)),
        ),
        Container(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: children.asMap().entries.map((e) {
              final isLast = e.key == children.length - 1;
              return Column(children: [
                e.value,
                if (!isLast) Divider(
                    color: p.border, height: 1,
                    indent: 48, endIndent: 0),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;
  const _PRow({
    required this.icon,
    this.iconColor,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final p      = AbodePalette.of(context);
    final icolor = isDestructive ? p.red : (iconColor ?? p.amber);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: icolor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: icolor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: isDestructive ? p.red : p.text,
                        fontSize: 14, fontWeight: FontWeight.w500)),
                if (subtitle?.isNotEmpty == true)
                  Text(subtitle!,
                      style: TextStyle(color: p.sub, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded, size: 17, color: p.muted),
        ]),
      ),
    );
  }
}

// ─── Cert requirements banner (Overview) ─────────────────────────────────────
class _CertRequirementsBanner extends ConsumerWidget {
  final ContractorDetails cp;
  const _CertRequirementsBanner({required this.cp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p        = AbodePalette.of(context);
    final certsAsync = ref.watch(contractorCertificationsProvider);
    final certs    = certsAsync.valueOrNull ?? [];
    final required = requiredCertsForWorkTypes(cp.workTypes);
    if (required.isEmpty) return const SizedBox.shrink();

    final verifiedTypes = certs
        .where((c) => c.isVerified)
        .map((c) => c.certType)
        .toList();

    // Build per-cert status rows for certs that are NOT yet verified
    final items = <_CertStatusItem>[];
    for (final certType in required) {
      final submitted = certs.where((c) => c.certType == certType ||
          (certType == 'niceic' && (c.certType == 'niceic' || c.certType == 'napit'))).toList();
      if (certSatisfied(certType, verifiedTypes)) continue; // already good

      final meta = kCertMeta[certType]!;
      if (submitted.isEmpty) {
        items.add(_CertStatusItem(certType: certType, meta: meta, status: 'missing', cert: null));
      } else {
        final latest = submitted.first;
        items.add(_CertStatusItem(certType: certType, meta: meta, status: latest.status, cert: latest));
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: p.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Icon(Icons.verified_user_outlined, size: 15, color: p.amber),
            const SizedBox(width: 6),
            Text('Certifications Required',
                style: TextStyle(
                    color: p.text, fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (certsAsync.isLoading)
              SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: p.amber)),
          ]),
        ),
        Container(height: 1, color: p.border),
        ...items.map((item) => _CertStatusRow(item: item, p: p)),
      ]),
    );
  }
}

class _CertStatusItem {
  final String certType;
  final CertMeta meta;
  final String status; // missing | pending | rejected | expired
  final ContractorCertification? cert;
  const _CertStatusItem({
    required this.certType,
    required this.meta,
    required this.status,
    required this.cert,
  });
}

class _CertStatusRow extends StatelessWidget {
  final _CertStatusItem item;
  final AbodePalette p;
  const _CertStatusRow({required this.item, required this.p});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.status) {
      'pending'  => p.blue,
      'rejected' => p.red,
      'expired'  => p.red,
      _          => p.amber, // missing
    };
    final statusLabel = switch (item.status) {
      'pending'  => 'Under Review',
      'rejected' => 'Rejected',
      'expired'  => 'Expired',
      _          => 'Required',
    };
    final actionLabel = switch (item.status) {
      'pending'  => null,
      'rejected' => 'Resubmit',
      _          => 'Upload',
    };

    return InkWell(
      onTap: actionLabel == null
          ? null
          : () => showCertUploadSheet(
                context,
                certType: item.certType,
                currentCertNumber: item.cert?.certNumber,
                rejectionReason: item.cert?.adminNotes,
              ),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(item.meta.icon, size: 16, color: item.meta.color),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text(item.meta.label,
                style: TextStyle(
                    color: p.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            if (item.status == 'rejected' &&
                item.cert?.adminNotes?.isNotEmpty == true)
              Text(item.cert!.adminNotes!,
                  style: TextStyle(color: p.red, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: p.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.amber.withValues(alpha: 0.3)),
              ),
              child: Text(actionLabel,
                  style: TextStyle(
                      color: p.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Available tab: cert warning strip ───────────────────────────────────────
class _AvailableCertWarning extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p          = AbodePalette.of(context);
    final certsAsync = ref.watch(contractorCertificationsProvider);
    final cpAsync    = ref.watch(contractorProfileProvider);
    final cp         = cpAsync.valueOrNull;
    final certs      = certsAsync.valueOrNull ?? [];
    if (cp == null || cp.workTypes.isEmpty) return const SizedBox.shrink();

    final required = requiredCertsForWorkTypes(cp.workTypes);
    if (required.isEmpty) return const SizedBox.shrink();

    final verifiedTypes =
        certs.where((c) => c.isVerified).map((c) => c.certType).toList();

    final missing = required
        .where((ct) => !certSatisfied(ct, verifiedTypes))
        .toList();
    if (missing.isEmpty) return const SizedBox.shrink();

    final hasPending = missing.any((ct) =>
        certs.any((c) => (c.certType == ct || (ct == 'niceic' && (c.certType == 'niceic' || c.certType == 'napit'))) && c.isPending));
    final hasRejected = missing.any((ct) =>
        certs.any((c) => (c.certType == ct || (ct == 'niceic' && (c.certType == 'niceic' || c.certType == 'napit'))) && c.isRejected));

    final color  = hasRejected ? p.red : p.amber;
    final icon   = hasRejected
        ? Icons.cancel_outlined
        : hasPending
            ? Icons.schedule_outlined
            : Icons.warning_amber_rounded;
    final message = hasRejected
        ? 'Some required certifications were rejected — resubmit to accept jobs'
        : hasPending
            ? 'Certifications under review — you can browse but may not be able to accept all jobs'
            : 'Upload required certifications to accept jobs in your trade';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _ExpiryChip extends StatelessWidget {
  final DateTime date;
  final AbodePalette p;
  const _ExpiryChip({required this.date, required this.p});

  @override
  Widget build(BuildContext context) {
    final days    = date.difference(DateTime.now()).inDays;
    final expired = days < 0;
    final color   = expired ? p.red : days <= 30 ? p.amber : p.green;
    final text    = expired
        ? 'Expired'
        : days == 0
            ? 'Today'
            : days <= 30 ? '${days}d' : '${(days / 30).floor()}mo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}
