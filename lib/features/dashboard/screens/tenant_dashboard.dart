import 'package:file_picker/file_picker.dart';
import 'package:flow_app/core/widgets/abode_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../../../core/widgets/role_sidebar.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/shimmer.dart';
import '../widgets/bento_stat.dart';
import '../models/incident.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/compliance_docs_panel.dart';
import '../widgets/create_incident_sheet.dart';
import '../widgets/deposit_dispute_sheet.dart';
import '../widgets/incident_card.dart';
import '../widgets/incident_comments_sheet.dart';
import '../widgets/rate_job_sheet.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/quote_review_sheet.dart';
import '../widgets/tenant_visit_confirm_sheet.dart';
import '../widgets/tenant_rent_sheet.dart';
import '../widgets/tenant_rights_sheet.dart';
import 'messaging_screen.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Role accent ──────────────────────────────────────────────────────────────
const _accent = Color(0xFF14B8A6);

// ─── Tabs ─────────────────────────────────────────────────────────────────────
enum _TTab { overview, home, maintenance, documents, messages }

// ─── Root ─────────────────────────────────────────────────────────────────────
class TenantDashboard extends ConsumerStatefulWidget {
  final UserProfile profile;
  const TenantDashboard({super.key, required this.profile});

  @override
  ConsumerState<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends ConsumerState<TenantDashboard> {
  _TTab _tab = _TTab.overview;
  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  @override
  Widget build(BuildContext context) =>
      _isMobile ? _buildMobile() : _buildDesktop();

  Widget _buildDesktop() {
    final p = AbodePalette.of(context);
    return Material(
      color: p.bg,
      child: Row(children: [
        RoleSidebar<_TTab>(
          profile:     widget.profile,
          accent:      _accent,
          roleLabel:   'tenant',
          tabs:        _TTab.values,
          activeTab:   _tab,
          onTabChange: (t) => setState(() => _tab = t),
          labelOf:     (t) => switch (t) {
            _TTab.overview    => 'Overview',
            _TTab.home        => 'My Home',
            _TTab.maintenance => 'Maintenance',
            _TTab.documents   => 'Documents',
            _TTab.messages    => 'Messages',
          },
          iconOf:      (t) => switch (t) {
            _TTab.overview    => Icons.grid_view_rounded,
            _TTab.home        => Icons.home_outlined,
            _TTab.maintenance => Icons.build_outlined,
            _TTab.documents   => Icons.folder_outlined,
            _TTab.messages    => Icons.chat_bubble_outline_rounded,
          },
          onSignOut:        _signOut,
          onNotifications:  () => showNotificationsSheet(context),
          onSettings:       () => showSettingsSheet(context,
              role: 'tenant', accent: _accent, onSignOut: _signOut),
        ),
        Expanded(child: _buildContent()),
      ]),
    );
  }

  Widget _buildMobile() {
    final p = AbodePalette.of(context);
    return Material(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          _MobileHeader(profile: widget.profile, onSignOut: _signOut),
          Expanded(child: _buildContent()),
          _MobileBottomNav(
            activeTab:   _tab,
            onTabChange: (t) => setState(() => _tab = t),
          ),
        ]),
      ),
    );
  }

  Widget _buildContent() => switch (_tab) {
    _TTab.overview    => _OverviewContent(
        profile:           widget.profile,
        onGoToHome:        () => setState(() => _tab = _TTab.home),
        onGoToMaintenance: () => setState(() => _tab = _TTab.maintenance)),
    _TTab.home        => _HomeContent(profile: widget.profile),
    _TTab.maintenance => _MaintenanceContent(profile: widget.profile),
    _TTab.documents   => const _DocumentsContent(),
    _TTab.messages    => const MessagingScreen(role: 'tenant'),
  };

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) context.go(AppRoutes.landing);
  }
}

// ─── Sign-out confirmation ────────────────────────────────────────────────────
Future<void> _confirmSignOut(BuildContext context, VoidCallback onSignOut) async {
  final confirmed = await showAbodeConfirmDialog(
    context,
    title: 'Sign out?',
    body: "You'll be returned to the home screen.",
    confirmLabel: 'Sign out',
    isDestructive: true,
    icon: Icons.logout_outlined,
  );
  if (confirmed == true && context.mounted) onSignOut();
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: p.surface,
      child: Row(children: [
        abodeLogo(),
        const SizedBox(width: 8),
        Text('Abode',
            style: TextStyle(
                color: p.text,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                letterSpacing: -0.3)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withValues(alpha: 0.35)),
          ),
          child: const Text('TENANT',
              style: TextStyle(
                  color: _accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ),
        const Spacer(),
        // Notification bell
        GestureDetector(
          onTap: () => showNotificationsSheet(context),
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
                  decoration: BoxDecoration(color: p.red, shape: BoxShape.circle),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w700)),
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
  final _TTab activeTab;
  final ValueChanged<_TTab> onTabChange;
  const _MobileBottomNav({
    required this.activeTab,
    required this.onTabChange,
  });

  static const _mobileIcons = {
    _TTab.overview:    Icons.grid_view_rounded,
    _TTab.home:        Icons.home_outlined,
    _TTab.maintenance: Icons.build_outlined,
    _TTab.documents:   Icons.folder_outlined,
    _TTab.messages:    Icons.chat_bubble_outline_rounded,
  };
  static const _mobileLabels = {
    _TTab.overview:    'Overview',
    _TTab.home:        'Home',
    _TTab.maintenance: 'Maintenance',
    _TTab.documents:   'Docs',
    _TTab.messages:    'Messages',
  };

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
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
            children: _TTab.values.map((t) {
              final a = t == activeTab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTabChange(t),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: a
                          ? _accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_mobileIcons[t]!, size: 22,
                            color: a ? _accent : p.muted),
                        const SizedBox(height: 3),
                        Text(_mobileLabels[t]!,
                            style: TextStyle(
                                fontSize: 10,
                                color: a ? _accent : p.muted,
                                fontWeight: a
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

// ─── Status helpers ───────────────────────────────────────────────────────────
String _humaniseStatus(String status) => switch (status.toLowerCase()) {
  'active'     => 'Active',
  'pending'    => 'Pending',
  'terminated' => 'Ended',
  'expired'    => 'Expired',
  'cancelled'  => 'Cancelled',
  _            => status[0].toUpperCase() + status.substring(1),
};

Color _statusColor(String status, AbodePalette p) => switch (status.toLowerCase()) {
  'active'  => p.green,
  'pending' => p.amber,
  _         => p.muted,
};

// ─── Shared helpers ───────────────────────────────────────────────────────────
Widget _emptyState(BuildContext context, String msg,
    {required IconData icon}) {
  final p = AbodePalette.of(context);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, color: p.muted, size: 26),
        ),
        const SizedBox(height: 16),
        Text(msg,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: p.sub, fontSize: 14, height: 1.5)),
      ]),
    ),
  );
}

Widget _sectionHeader(BuildContext context, String title,
    {Widget? action}) {
  final p = AbodePalette.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    child: Row(children: [
      Expanded(
        child: Text(title,
            style: TextStyle(
                color: p.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3)),
      ),
      if (action != null) action,
    ]),
  );
}

// ─── Rent countdown card ──────────────────────────────────────────────────────
class _RentCountdownCard extends ConsumerWidget {
  final Tenancy tenancy;
  const _RentCountdownCard({required this.tenancy});

  DateTime _nextRentDate() {
    final now      = DateTime.now();
    final startDay = tenancy.startDate?.day ?? 1;
    var candidate  = DateTime(now.year, now.month, startDay);
    if (candidate.isBefore(now)) {
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear  = now.month == 12 ? now.year + 1 : now.year;
      candidate = DateTime(nextYear, nextMonth, startDay);
    }
    return candidate;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p        = AbodePalette.of(context);
    final rent     = tenancy.monthlyRent!;
    final nextDue  = _nextRentDate();
    final daysLeft = nextDue.difference(DateTime.now()).inDays;
    final fmt      = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    final color    = daysLeft <= 3 ? p.red : daysLeft <= 7 ? p.amber : _accent;

    final hasEndDate  = tenancy.endDate != null && tenancy.startDate != null;
    double? progress;
    int? daysUntilEnd;
    if (hasEndDate) {
      final total   = tenancy.endDate!.difference(tenancy.startDate!).inDays;
      final elapsed = DateTime.now().difference(tenancy.startDate!).inDays;
      progress      = (total > 0 ? elapsed / total : 0.0).clamp(0.0, 1.0);
      daysUntilEnd  = tenancy.endDate!.difference(DateTime.now()).inDays;
    }

    // Check if current period's rent has been paid
    final payments = ref.watch(rentPaymentsProvider(tenancy.tenancyId)).valueOrNull ?? [];
    final currentPayment = payments.where((pay) =>
      pay.dueDate.year == nextDue.year && pay.dueDate.month == nextDue.month
    ).firstOrNull;
    final isPaid = currentPayment?.isPaid ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (isPaid ? p.green : color).withValues(alpha: 0.3)),
        boxShadow: p.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: (isPaid ? p.green : color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isPaid ? Icons.check_circle_outline_rounded : Icons.payments_outlined,
              color: isPaid ? p.green : color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Next rent: ${fmt.format(rent)}',
                  style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                isPaid
                    ? 'Paid — awaiting confirmation'
                    : 'Due ${nextDue.day}/${nextDue.month}/${nextDue.year}'
                      ' · ${daysLeft == 0 ? "Today!" : daysLeft == 1 ? "Tomorrow" : "in $daysLeft days"}',
                style: TextStyle(color: isPaid ? p.green : color, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          // Pay button or paid badge
          GestureDetector(
            onTap: () => showTenantRentSheet(context, tenancy: tenancy, dueDate: nextDue),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPaid
                    ? p.green.withValues(alpha: 0.12)
                    : _accent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isPaid ? null : [
                  BoxShadow(color: _accent.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                isPaid ? 'Paid ✓' : 'Pay',
                style: TextStyle(
                  color: isPaid ? p.green : Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ]),
        if (hasEndDate && progress != null && daysUntilEnd != null && daysUntilEnd >= 0) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tenancy progress', style: TextStyle(color: p.sub, fontSize: 11)),
              Text(
                daysUntilEnd > 0 ? '$daysUntilEnd days remaining' : 'Ends today',
                style: TextStyle(color: p.sub, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: p.border,
              valueColor: AlwaysStoppedAnimation(daysUntilEnd <= 60 ? p.amber : _accent),
              minHeight: 5,
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Overview ─────────────────────────────────────────────────────────────────
class _OverviewContent extends ConsumerWidget {
  final UserProfile profile;
  final VoidCallback onGoToHome;
  final VoidCallback onGoToMaintenance;
  const _OverviewContent({
    required this.profile,
    required this.onGoToHome,
    required this.onGoToMaintenance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p            = AbodePalette.of(context);
    final tenanciesAsync = ref.watch(tenantTenanciesProvider);
    final incidentsAsync = ref.watch(tenantIncidentsProvider);
    final tenancies    = tenanciesAsync.valueOrNull ?? [];
    final incidents    = incidentsAsync.valueOrNull ?? [];
    final active       = tenancies.where((t) => t.status == 'active').toList();
    final pending      = tenancies.where((t) => t.status == 'pending').toList();
    final openIssues   = incidents.where((i) => i.status != 'completed').length;
    final isDesktop    = MediaQuery.of(context).size.width >= 700;

    // ── Welcome banner — desktop only, lightweight text header ────────────────
    final welcomeBanner = isDesktop
        ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                active.isNotEmpty ? active.first.addressLine1 : 'Overview',
                style: TextStyle(color: p.text, fontSize: 22,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              if (active.isNotEmpty)
                Text(active.first.postcode,
                    style: TextStyle(color: p.sub, fontSize: 13)),
            ]),
          )
        : const SizedBox.shrink();

    // ── Left-column content ────────────────────────────────────────────────────
    Widget leftColumn() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rent countdown — hero position
        if (active.isNotEmpty && active.first.monthlyRent != null)
          Padding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 0 : 20, isDesktop ? 12 : 20, isDesktop ? 0 : 20, 16),
            child: _RentCountdownCard(tenancy: active.first),
          ),

        // Stats — mobile only (desktop has My Home sidebar + sidebar context)
        if (!isDesktop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              BentoStat(
                value: '${active.length}',
                label: 'Active',
                icon: Icons.home_outlined,
                color: _accent,
                onTap: onGoToHome,
              ),
              const SizedBox(width: 10),
              BentoStat(
                value: '$openIssues',
                label: 'Maintenance',
                icon: Icons.build_outlined,
                color: openIssues > 0 ? p.amber : p.green,
                onTap: onGoToMaintenance,
              ),
            ]),
          ),

        // Pending invitations — slim nudge banner, tap to go to My Home
        if (pending.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 0 : 20, 12, isDesktop ? 0 : 20, 0),
            child: GestureDetector(
              onTap: onGoToHome,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.mail_outline_rounded, color: _accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${pending.length} pending invitation${pending.length > 1 ? 's' : ''} — tap to review',
                      style: TextStyle(color: _accent, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _accent, size: 18),
                ]),
              ),
            ),
          ),

        // Recent issues
        _sectionHeader(context, 'Maintenance',
            action: GestureDetector(
              onTap: onGoToMaintenance,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text('See all',
                    style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            )),
        incidentsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: _accent, strokeWidth: 2),
            ),
          ),
          error: (_, __) =>
              _emptyState(context, 'Could not load',
                  icon: Icons.error_outline),
          data: (list) {
            final open = list
                .where((i) => i.status != 'completed')
                .take(3)
                .toList();
            if (open.isEmpty) {
              return _emptyState(context, 'No open issues.',
                  icon: Icons.check_circle_outline);
            }
            return Column(
              children: open
                  .map((i) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: IncidentCard(
                          incident: i,
                          role: 'tenant',
                          currentUserId:
                              supabase.auth.currentUser?.id ?? '',
                          onAction: (action) async {
                            if (action == 'tenant_complete') {
                              final fullyDone = await ref
                                  .read(tenantMarkCompleteProvider.notifier)
                                  .markComplete(i.id);
                              if (fullyDone &&
                                  i.contractorId != null &&
                                  context.mounted) {
                                await showRateJobSheet(context,
                                    incidentId: i.id,
                                    contractorId: i.contractorId!,
                                    contractorName:
                                        i.contractorName ?? 'Contractor');
                              }
                            } else if (action == 'confirm_visit') {
                              if (context.mounted) {
                                showTenantVisitConfirmSheet(context,
                                    incident: i);
                              }
                            } else if (action == 'review_quote') {
                              if (context.mounted) {
                                showQuoteReviewSheet(context, incident: i);
                              }
                            }
                          },
                          onViewThread: () => showIncidentCommentsSheet(
                              context,
                              incidentId: i.id,
                              incidentTitle: i.title,
                              role: 'tenant'),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );

    // ── Right-column content (My Home) ─────────────────────────────────────────
    Widget rightColumn() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'My Home'),
        tenanciesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: _accent, strokeWidth: 2),
            ),
          ),
          error: (_, __) =>
              _emptyState(context, 'Could not load',
                  icon: Icons.error_outline),
          data: (list) {
            if (active.isEmpty) {
              return _emptyState(context, 'No active tenancy yet.',
                  icon: Icons.home_outlined);
            }
            final t = active.first;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _OverviewTenancyCard(tenancy: t),
            );
          },
        ),
      ],
    );

    return RefreshIndicator(
      color: _accent,
      onRefresh: () async {
        ref.invalidate(tenantTenanciesProvider);
        ref.invalidate(tenantIncidentsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          welcomeBanner,
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: leftColumn()),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: rightColumn()),
                ],
              ),
            )
          else ...[
            leftColumn(),
            rightColumn(),
            const SizedBox(height: 32),
          ],
        ]),
      ),
    );
  }
}

// ─── Application card (pending invite) — compact, tap to view details ────────
class _ApplicationCard extends ConsumerWidget {
  final Tenancy tenancy;
  const _ApplicationCard({required this.tenancy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final t = tenancy;
    final submitted = t.offerSubmittedAt != null;
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: submitted
              ? p.green.withValues(alpha: 0.35)
              : _accent.withValues(alpha: 0.25),
        ),
        boxShadow: p.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          // Icon
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: submitted
                  ? p.green.withValues(alpha: 0.12)
                  : _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              submitted ? Icons.check_circle_outline : Icons.mail_outline,
              color: submitted ? p.green : _accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Address + landlord + rent preview
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.shortAddress,
                  style: TextStyle(
                      color: p.text, fontSize: 14,
                      fontWeight: FontWeight.w700, letterSpacing: -0.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              if (t.landlord?.fullName != null)
                Text('From ${t.landlord!.fullName}',
                    style: TextStyle(color: p.sub, fontSize: 12)),
              if (t.monthlyRent != null)
                Text(
                  '${fmt.format(t.monthlyRent!)}/mo · ${submitted ? "Applied" : "Invited"}',
                  style: TextStyle(
                    color: submitted ? p.green : _accent,
                    fontSize: 12, fontWeight: FontWeight.w600,
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          // View button
          GestureDetector(
            onTap: () => _showDetail(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )
                ],
              ),
              child: const Text('View',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteDetailSheet(tenancy: tenancy, ref: ref),
    );
  }
}

// ─── Invite detail sheet ──────────────────────────────────────────────────────
class _InviteDetailSheet extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  final WidgetRef ref;
  const _InviteDetailSheet({required this.tenancy, required this.ref});

  @override
  ConsumerState<_InviteDetailSheet> createState() => _InviteDetailSheetState();
}

class _InviteDetailSheetState extends ConsumerState<_InviteDetailSheet> {
  bool _declining = false;

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final t = widget.tenancy;
    final submitted = t.offerSubmittedAt != null;
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: p.border, borderRadius: BorderRadius.circular(2)),
            )),

            // Title row
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rental Invitation',
                      style: TextStyle(color: p.text, fontSize: 20,
                          fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  if (t.landlord?.fullName != null)
                    Text('From ${t.landlord!.fullName}',
                        style: TextStyle(color: p.sub, fontSize: 13)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: submitted
                      ? p.green.withValues(alpha: 0.12)
                      : _accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  submitted ? 'Applied' : 'Invited',
                  style: TextStyle(
                    color: submitted ? p.green : _accent,
                    fontSize: 12, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Property address block
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border),
              ),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home_outlined, color: _accent, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.addressLine1,
                      style: TextStyle(color: p.text, fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(t.postcode,
                      style: TextStyle(color: p.sub, fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 12),

            // Spec chips
            if (t.numBedrooms != null || t.numBathrooms != null || t.propertyType != null)
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (t.numBedrooms  != null) _InviteChip(Icons.bed_outlined,     '${t.numBedrooms} bed', p),
                if (t.numBathrooms != null) _InviteChip(Icons.bathtub_outlined, '${t.numBathrooms} bath', p),
                if (t.propertyType != null) _InviteChip(Icons.home_outlined,
                    '${t.propertyType![0].toUpperCase()}${t.propertyType!.substring(1)}', p),
              ]),
            const SizedBox(height: 16),

            // Rent & deposit
            Container(
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border),
              ),
              child: Row(children: [
                Expanded(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Monthly rent',
                        style: TextStyle(color: p.muted, fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(t.monthlyRent != null ? fmt.format(t.monthlyRent!) : '—',
                        style: TextStyle(color: p.text, fontSize: 22,
                            fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    if (t.monthlyRent != null)
                      Text('${fmt.format(t.monthlyRent! * 12)}/year',
                          style: TextStyle(color: p.sub, fontSize: 11)),
                  ]),
                )),
                Container(width: 1, height: 70, color: p.border),
                Expanded(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Deposit',
                        style: TextStyle(color: p.muted, fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(t.depositAmount != null ? fmt.format(t.depositAmount!) : '—',
                        style: TextStyle(color: p.text, fontSize: 22,
                            fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    if (t.monthlyRent != null && t.depositAmount != null)
                      Text('${(t.depositAmount! / (t.monthlyRent! * 12 / 52)).toStringAsFixed(1)} weeks\' rent',
                          style: TextStyle(color: p.sub, fontSize: 11)),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 24),

            // Action area
            if (submitted) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.green.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.green.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.hourglass_top_rounded, size: 16, color: p.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                      'Application submitted — awaiting landlord review',
                      style: TextStyle(color: p.green, fontSize: 13,
                          fontWeight: FontWeight.w600))),
                ]),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _showApplicationSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: _accent.withValues(alpha: 0.3),
                          blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    alignment: Alignment.center,
                    child: const Text('Accept & Apply',
                        style: TextStyle(color: Colors.white,
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _declining ? null : _decline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    alignment: Alignment.center,
                    child: _declining
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Decline invitation',
                            style: TextStyle(color: p.muted,
                                fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    ),
    );
  }

  Future<void> _decline() async {
    setState(() => _declining = true);
    final ok = await widget.ref.read(acceptInvitationProvider.notifier).decline(widget.tenancy.id);
    if (mounted) {
      if (ok) Navigator.pop(context);
      else setState(() => _declining = false);
    }
  }

  void _showApplicationSheet(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TenantApplicationSheet(tenancy: widget.tenancy, ref: widget.ref),
    );
  }
}

// ─── Invite detail helpers ────────────────────────────────────────────────────
class _InviteChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AbodePalette p;
  const _InviteChip(this.icon, this.label, this.p);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: p.border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: p.sub),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _InviteFinancial extends StatelessWidget {
  final String label, value;
  final String? sub;
  final AbodePalette p;
  const _InviteFinancial({required this.label, required this.value, this.sub, required this.p});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      if (sub != null) Text(sub!, style: TextStyle(color: p.sub, fontSize: 11)),
    ]),
  );
}

// ─── Tenant application form sheet ────────────────────────────────────────────
class _TenantApplicationSheet extends StatefulWidget {
  final Tenancy tenancy;
  final WidgetRef ref;
  const _TenantApplicationSheet({required this.tenancy, required this.ref});
  @override
  State<_TenantApplicationSheet> createState() => _TenantApplicationSheetState();
}

class _TenantApplicationSheetState extends State<_TenantApplicationSheet> {
  final _incomeCtrl  = TextEditingController();
  final _messageCtrl = TextEditingController();
  String? _employment;
  DateTime? _moveIn;
  bool _saving = false;

  static const _employmentOptions = [
    ('employed',      'Employed'),
    ('self_employed', 'Self-employed'),
    ('student',       'Student'),
    ('unemployed',    'Unemployed'),
    ('retired',       'Retired'),
  ];

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _employment != null && !_saving;

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle
              Center(child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),

              Text('Your Application',
                  style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 4),
              Text(widget.tenancy.shortAddress,
                  style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 24),

              // Employment status
              _AppLabel('EMPLOYMENT STATUS', p),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: _employmentOptions.map(((String, String) opt) {
                final selected = _employment == opt.$1;
                return GestureDetector(
                  onTap: () => setState(() => _employment = opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? _accent.withValues(alpha: 0.12) : p.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _accent.withValues(alpha: 0.5) : p.border,
                        width: selected ? 1.5 : 0.8,
                      ),
                    ),
                    child: Text(opt.$2,
                        style: TextStyle(
                          color: selected ? _accent : p.sub,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ),
                );
              }).toList()),
              const SizedBox(height: 18),

              // Annual income
              _AppLabel('ANNUAL INCOME (OPTIONAL)', p),
              const SizedBox(height: 8),
              TextField(
                controller: _incomeCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: p.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '30000',
                  hintStyle: TextStyle(color: p.muted),
                  prefixText: '£',
                  prefixStyle: TextStyle(color: p.sub),
                  filled: true, fillColor: p.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accent, width: 1.5)),
                ),
              ),
              const SizedBox(height: 18),

              // Preferred move-in
              _AppLabel('PREFERRED MOVE-IN DATE (OPTIONAL)', p),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showAbodeDatePicker(
                    context,
                    initialDate: DateTime.now().add(const Duration(days: 14)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _moveIn = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _moveIn != null ? _accent.withValues(alpha: 0.5) : p.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 16,
                        color: _moveIn != null ? _accent : p.muted),
                    const SizedBox(width: 10),
                    Text(
                      _moveIn != null
                          ? DateFormat('d MMMM yyyy').format(_moveIn!)
                          : 'Select a date',
                      style: TextStyle(color: _moveIn != null ? p.text : p.muted, fontSize: 15),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 18),

              // Message
              _AppLabel('MESSAGE TO LANDLORD (OPTIONAL)', p),
              const SizedBox(height: 8),
              TextField(
                controller: _messageCtrl,
                maxLines: 4,
                style: TextStyle(color: p.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Introduce yourself and explain why you\'d be a great tenant…',
                  hintStyle: TextStyle(color: p.muted, fontSize: 14),
                  filled: true, fillColor: p.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accent, width: 1.5)),
                ),
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _canSubmit ? _submit : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: _canSubmit ? _accent : p.border,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _employment == null ? 'Select employment status' : 'Submit Application',
                            style: TextStyle(
                              color: _canSubmit ? Colors.white : p.muted,
                              fontSize: 15, fontWeight: FontWeight.w700,
                            )),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_employment == null) return;
    setState(() => _saving = true);
    try {
      final user = supabase.auth.currentUser!;
      final income = double.tryParse(_incomeCtrl.text.trim().replaceAll(',', ''));
      final message = _messageCtrl.text.trim();
      await supabase.from('tenancies').update({
        'tenant_id': user.id,
        'tenant_employment_status': _employment,
        if (income != null) 'tenant_annual_income': income,
        if (_moveIn != null) 'tenant_move_in_preference': _moveIn!.toIso8601String(),
        if (message.isNotEmpty) 'tenant_message': message,
        'offer_submitted_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.tenancy.id);

      widget.ref.invalidate(tenantTenanciesProvider);

      if (mounted) {
        Navigator.pop(context);
        showAbodeToast(context, 'Application submitted — your landlord will be in touch');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAbodeToast(context, 'Failed: $e', isError: true);
      }
    }
  }
}

class _AppLabel extends StatelessWidget {
  final String text;
  final AbodePalette p;
  const _AppLabel(this.text, this.p);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: p.sub, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4));
}

// ─── Home tab ─────────────────────────────────────────────────────────────────
class _HomeContent extends ConsumerWidget {
  final UserProfile profile;
  const _HomeContent({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenanciesAsync = ref.watch(tenantTenanciesProvider);
    return RefreshIndicator(
      color: _accent,
      onRefresh: () async => ref.invalidate(tenantTenanciesProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(context, 'My Home'),
        Expanded(
          child: tenanciesAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: _accent, strokeWidth: 2)),
            error: (_, __) => _emptyState(context, 'Could not load', icon: Icons.error_outline),
            data: (list) {
              final pending = list.where((t) => t.status == 'pending').toList();
              final active  = list.where((t) => t.status == 'active').toList();
              if (pending.isEmpty && active.isEmpty) {
                return _emptyState(context, 'No active tenancy yet.', icon: Icons.home_outlined);
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  // ── Pending invitations ────────────────────────────────
                  if (pending.isNotEmpty) ...[
                    _HomeSection(label: 'Pending Invitation${pending.length > 1 ? 's' : ''}'),
                    ...pending.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InvitationCard(tenancy: t, ref: ref),
                    )),
                    if (active.isNotEmpty) const SizedBox(height: 8),
                  ],

                  // ── Active tenancies ───────────────────────────────────
                  if (active.isNotEmpty) ...[
                    if (pending.isNotEmpty) _HomeSection(label: 'Your Home'),
                    ...active.map((t) => _ActiveTenancySection(tenancy: t)),
                  ],
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── Section sub-label ─────────────────────────────────────────────────────────
class _HomeSection extends StatelessWidget {
  final String label;
  const _HomeSection({required this.label});
  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
          style: TextStyle(color: p.sub, fontSize: 12,
              fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    );
  }
}

// ─── Pending invitation card (in My Home) ────────────────────────────────────
class _InvitationCard extends ConsumerWidget {
  final Tenancy tenancy;
  final WidgetRef ref;
  const _InvitationCard({required this.tenancy, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p   = AbodePalette.of(context);
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    final t   = tenancy;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _InviteDetailSheet(tenancy: t, ref: ref),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.3)),
          boxShadow: p.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mail_outline_rounded, color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.addressLine1,
                  style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (t.landlord?.fullName != null)
                Text('From ${t.landlord!.fullName}',
                    style: TextStyle(color: p.sub, fontSize: 12)),
              if (t.monthlyRent != null)
                Text('${fmt.format(t.monthlyRent!)}/mo',
                    style: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ─── Active tenancy section (full redesign) ───────────────────────────────────
class _ActiveTenancySection extends StatelessWidget {
  final Tenancy tenancy;
  const _ActiveTenancySection({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final p   = AbodePalette.of(context);
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    final t   = tenancy;
    final hasDeposit   = (t.depositAmount ?? 0) > 0;
    final depositProtected = t.depositRef != null && t.depositRef!.isNotEmpty;
    final hasShareCode = t.rtrShareCode != null && t.rtrShareCode!.isNotEmpty;
    final rtrVerified  = t.rtrStatus == 'completed';
    final hasRtrDoc    = t.rtrDocumentUrl != null && t.rtrDocumentUrl!.isNotEmpty;

    final now = DateTime.now();
    double? progress;
    int? daysLeft;
    if (t.startDate != null && t.endDate != null) {
      final total   = t.endDate!.difference(t.startDate!).inDays;
      final elapsed = now.difference(t.startDate!).inDays;
      progress  = (total > 0) ? (elapsed / total).clamp(0.0, 1.0) : null;
      daysLeft  = t.endDate!.difference(now).inDays;
    }
    final hasRentReview = t.nextRentReviewDate != null &&
        t.nextRentReviewDate!.isAfter(now) &&
        t.nextRentReviewDate!.difference(now).inDays <= 60;

    // Items needing attention
    final alerts = <_AlertItem>[
      if (hasDeposit && !depositProtected)
        _AlertItem(
          icon: Icons.account_balance_outlined,
          color: const Color(0xFFF59E0B),
          title: 'Deposit not protected',
          subtitle: '${fmt.format(t.depositAmount)} — chase your landlord to register it',
        ),
      if (hasRentReview)
        _AlertItem(
          icon: Icons.event_note_outlined,
          color: const Color(0xFFF59E0B),
          title: 'Rent review coming up',
          subtitle: 'Due ${_fmtDate(t.nextRentReviewDate!)} — ${t.nextRentReviewDate!.difference(now).inDays} days away',
        ),
      if (t.noticeServedDate != null && t.noticeGivenBy == 'landlord')
        _AlertItem(
          icon: Icons.gavel_outlined,
          color: const Color(0xFFEF4444),
          title: 'Notice to vacate served',
          subtitle: t.expectedVacateDate != null
              ? 'Expected to vacate ${_fmtDate(t.expectedVacateDate!)}'
              : 'A notice has been served on your tenancy',
        ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── 1. Property hero ─────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.border),
          boxShadow: p.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.home_rounded, color: _accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.addressLine1,
                  style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(t.postcode, style: TextStyle(color: p.sub, fontSize: 13)),
            ])),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor(t.status, p).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_humaniseStatus(t.status),
                  style: TextStyle(color: _statusColor(t.status, p),
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ),
          ]),

          const SizedBox(height: 18),

          // Stats: 2-column pill tiles
          Row(children: [
            if (t.monthlyRent != null)
              Expanded(child: _StatTile(
                label: 'Monthly rent',
                value: fmt.format(t.monthlyRent!),
                icon: Icons.payments_outlined,
                color: _accent,
                p: p,
              )),
            if (t.monthlyRent != null && t.landlord?.fullName != null)
              const SizedBox(width: 10),
            if (t.landlord?.fullName != null)
              Expanded(child: _StatTile(
                label: 'Landlord',
                value: t.landlord!.fullName!,
                icon: Icons.person_outline_rounded,
                color: const Color(0xFF8B5CF6),
                p: p,
              )),
          ]),

          if (hasDeposit) ...[
            const SizedBox(height: 10),
            _DepositTile(tenancy: t, fmt: fmt, p: p),
          ],

          // Tenancy dates + progress
          if (t.startDate != null && t.endDate != null) ...[
            const SizedBox(height: 16),
            Divider(color: p.border, height: 1),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Lease', style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text('${_fmtShort(t.startDate!)} → ${_fmtShort(t.endDate!)}',
                    style: TextStyle(color: p.sub, fontSize: 13)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(daysLeft != null && daysLeft > 0 ? '$daysLeft days left' : 'Ended',
                    style: TextStyle(
                      color: daysLeft != null && daysLeft <= 60 ? p.amber : p.text,
                      fontSize: 15, fontWeight: FontWeight.w800,
                    )),
                Text('remaining', style: TextStyle(color: p.muted, fontSize: 10)),
              ]),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress ?? 0,
                minHeight: 6,
                backgroundColor: p.border,
                valueColor: AlwaysStoppedAnimation(
                  daysLeft != null && daysLeft <= 60 ? p.amber : _accent),
              ),
            ),
          ],
        ]),
      ),

      // ── 2. Next rent countdown ───────────────────────────────────────
      if (t.monthlyRent != null) ...[
        const SizedBox(height: 12),
        _RentCountdownCard(tenancy: t),
      ],

      // ── 3. Alerts — things that need attention ───────────────────────
      if (alerts.isNotEmpty) ...[
        const SizedBox(height: 20),
        _HomeSectionLabel(label: 'Needs attention', count: alerts.length),
        const SizedBox(height: 8),
        ...alerts.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _AlertCard(item: a, p: p),
        )),
      ],

      // ── 4. Compliance checklist ──────────────────────────────────────
      const SizedBox(height: 20),
      _HomeSectionLabel(label: 'Right to Rent',
          subtitle: rtrVerified && hasShareCode ? 'All complete' : null,
          allGood: rtrVerified && hasShareCode),
      const SizedBox(height: 8),
      _RightToRentShareCodeCard(tenancy: t),
      const SizedBox(height: 8),
      _RightToRentUploadCard(tenancy: t),

      // ── 5. Resources — with descriptions so tenants know why to tap ──
      const SizedBox(height: 20),
      _HomeSectionLabel(label: 'Resources'),
      const SizedBox(height: 8),
      if (hasDeposit) ...[
        _ResourceCard(
          icon: Icons.account_balance_outlined,
          color: const Color(0xFF8B5CF6),
          title: 'Deposit Dispute Helper',
          description: 'Understand what your landlord can legally deduct'
              ' and build your case if you think a claim is unfair.',
          onTap: () => showDepositDisputeSheet(context, tenancy: t),
          p: p,
        ),
        const SizedBox(height: 8),
      ],
      _ResourceCard(
        icon: Icons.balance_outlined,
        color: _accent,
        title: 'Know Your Rights',
        description: 'UK tenant rights on repairs, eviction, privacy'
            ' and rent increases — explained in plain English.',
        onTap: () => showTenantRightsSheet(context),
        p: p,
      ),
      const SizedBox(height: 32),
    ]);
  }

  static String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  static String _fmtShort(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ─── Alert item data ──────────────────────────────────────────────────────────
class _AlertItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _AlertItem({required this.icon, required this.color,
      required this.title, required this.subtitle});
}

// ─── Stat tile (coloured pill) ────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final AbodePalette p;
  const _StatTile({required this.label, required this.value,
      required this.icon, required this.color, required this.p});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.w500)),
        Text(value,
            style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

// ─── Deposit tile ─────────────────────────────────────────────────────────────
class _DepositTile extends StatelessWidget {
  final Tenancy tenancy;
  final NumberFormat fmt;
  final AbodePalette p;
  const _DepositTile({required this.tenancy, required this.fmt, required this.p});
  @override
  Widget build(BuildContext context) {
    final t = tenancy;
    final protected = t.depositRef != null && t.depositRef!.isNotEmpty;
    final color = protected ? p.green : p.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline_rounded, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Deposit', style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.w500)),
          Text(fmt.format(t.depositAmount),
              style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w700)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            protected ? '${t.depositScheme ?? "DPS"} Protected' : 'Not protected',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}

// ─── Section label with optional status ──────────────────────────────────────
class _HomeSectionLabel extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool allGood;
  final int? count;
  const _HomeSectionLabel({required this.label, this.subtitle, this.allGood = false, this.count});
  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Row(children: [
      Text(label, style: TextStyle(color: p.sub, fontSize: 12,
          fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      if (count != null) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: p.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(color: p.amber, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
      if (allGood) ...[
        const SizedBox(width: 6),
        Icon(Icons.check_circle_rounded, size: 13, color: p.green),
      ],
      if (subtitle != null) ...[
        const Spacer(),
        Text(subtitle!, style: TextStyle(color: p.green, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    ]);
  }
}

// ─── Alert card ───────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final _AlertItem item;
  final AbodePalette p;
  const _AlertCard({required this.item, required this.p});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: item.color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: item.color.withValues(alpha: 0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(item.icon, size: 17, color: item.color),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.title,
            style: TextStyle(color: item.color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(item.subtitle,
            style: TextStyle(color: item.color.withValues(alpha: 0.8), fontSize: 12, height: 1.4)),
      ])),
    ]),
  );
}

// ─── Resource card (with description) ────────────────────────────────────────
class _ResourceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;
  final AbodePalette p;
  const _ResourceCard({required this.icon, required this.color, required this.title,
      required this.description, required this.onTap, required this.p});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: p.cardShadow,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(description,
              style: TextStyle(color: p.sub, fontSize: 12, height: 1.45)),
        ])),
        const SizedBox(width: 8),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: p.muted),
      ]),
    ),
  );
}

// ─── Right to Rent share code card ───────────────────────────────────────────
class _RightToRentShareCodeCard extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  const _RightToRentShareCodeCard({required this.tenancy});

  @override
  ConsumerState<_RightToRentShareCodeCard> createState() =>
      _RightToRentShareCodeCardState();
}

class _RightToRentShareCodeCardState
    extends ConsumerState<_RightToRentShareCodeCard> {
  late final TextEditingController _ctrl;
  bool _editing = false;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.tenancy.rtrShareCode ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final code = _ctrl.text.trim().toUpperCase();
    setState(() => _saving = true);
    try {
      await supabase.from('tenancies')
          .update({'rtr_share_code': code.isEmpty ? null : code})
          .eq('id', widget.tenancy.id);
      ref.invalidate(tenantTenanciesProvider);
      if (mounted) setState(() { _editing = false; });
    } catch (_) {
      if (mounted) {
        showAbodeToast(context, 'Failed to save — try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final code = widget.tenancy.rtrShareCode;
    final hasCode = code != null && code.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: p.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user_outlined,
                color: Color(0xFF3B82F6), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Right to Rent',
                  style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Share your Home Office code with your landlord',
                  style: TextStyle(color: p.sub, fontSize: 11)),
            ]),
          ),
          if (hasCode && !_editing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Shared',
                  style: TextStyle(color: Color(0xFF22C55E),
                      fontSize: 10, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 12),
        if (_editing) ...[
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: p.text, fontSize: 15,
                fontWeight: FontWeight.w600, letterSpacing: 1.5),
            decoration: InputDecoration(
              hintText: 'e.g. W12 34T',
              hintStyle: TextStyle(color: p.muted, fontSize: 14,
                  fontWeight: FontWeight.w400, letterSpacing: 0),
              filled: true,
              fillColor: p.bg,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _editing = false),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.border),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(color: p.muted, fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save code',
                          style: TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ]),
        ] else ...[
          if (hasCode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: p.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border, width: 0.5),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(code!,
                      style: TextStyle(color: p.text, fontSize: 16,
                          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                ),
                GestureDetector(
                  onTap: () => setState(() { _editing = true; }),
                  child: Icon(Icons.edit_outlined, size: 16, color: p.muted),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Your landlord can see this code and use it on Gov.uk to complete your Right to Rent check.',
                style: TextStyle(color: p.muted, fontSize: 11, height: 1.4)),
          ] else ...[
            Text('Get your share code from the Home Office website and enter it here. Your landlord can then use it to complete the Right to Rent check without needing to see your documents.',
                style: TextStyle(color: p.sub, fontSize: 12, height: 1.5)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: Container(
                width: double.infinity,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                ),
                child: const Text('Enter share code',
                    style: TextStyle(color: Color(0xFF3B82F6),
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ]),
    );
  }
}

// ─── RTR document upload card ─────────────────────────────────────────────────
const _kRtrDocTypes = [
  'UK/EU Passport',
  'Biometric Residence Permit',
  'UK Driving Licence + Birth Certificate',
  'Certificate of Registration',
  'Immigration Status Document',
  'Other acceptable document',
];

class _RightToRentUploadCard extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  const _RightToRentUploadCard({required this.tenancy});
  @override
  ConsumerState<_RightToRentUploadCard> createState() => _RightToRentUploadCardState();
}

class _RightToRentUploadCardState extends ConsumerState<_RightToRentUploadCard> {
  bool _uploading = false;
  bool _showPicker = false;
  String? _selectedDocType;

  static const _blue = Color(0xFF3B82F6);

  bool get _hasUpload => widget.tenancy.rtrDocumentUrl != null && widget.tenancy.rtrDocumentUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final verified = widget.tenancy.rtrStatus == 'completed';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: p.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: verified
                  ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                  : _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              verified ? Icons.verified_rounded : Icons.upload_file_outlined,
              color: verified ? const Color(0xFF22C55E) : _blue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Right to Rent Document',
                style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(
              verified
                  ? 'Verified by landlord'
                  : _hasUpload
                      ? 'Uploaded — awaiting landlord verification'
                      : 'Upload your passport or right to rent document',
              style: TextStyle(color: p.sub, fontSize: 11),
            ),
          ])),
          if (verified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Verified',
                  style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.w700)),
            ),
        ]),

        if (!verified) ...[
          const SizedBox(height: 12),

          if (_hasUpload && !_showPicker) ...[
            // Already uploaded — show status + re-upload option
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _blue.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Icon(Icons.insert_drive_file_outlined, size: 14, color: _blue),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  widget.tenancy.rtrTenantDocType ?? 'Document uploaded',
                  style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w500),
                )),
                GestureDetector(
                  onTap: () => setState(() { _showPicker = true; _selectedDocType = widget.tenancy.rtrTenantDocType; }),
                  child: Text('Replace', style: TextStyle(color: p.muted, fontSize: 11)),
                ),
              ]),
            ),
          ] else ...[
            // Doc type picker
            Text('SELECT DOCUMENT TYPE',
                style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6,
              children: _kRtrDocTypes.map((type) {
                final sel = _selectedDocType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDocType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? _blue.withValues(alpha: 0.1) : p.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? _blue.withValues(alpha: 0.5) : p.border,
                        width: sel ? 1.5 : 0.8,
                      ),
                    ),
                    child: Text(type,
                        style: TextStyle(
                          color: sel ? _blue : p.sub,
                          fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: (_selectedDocType != null && !_uploading) ? _pickAndUpload : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedDocType != null ? _blue : p.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: _uploading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.upload_rounded, size: 16,
                              color: _selectedDocType != null ? Colors.white : p.muted),
                          const SizedBox(width: 6),
                          Text(
                            _selectedDocType == null ? 'Select document type above' : 'Upload document',
                            style: TextStyle(
                              color: _selectedDocType != null ? Colors.white : p.muted,
                              fontSize: 13, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                ),
              ),
            ),
          ],
        ],
      ]),
    );
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final ext = file.extension ?? 'jpg';
      final path = 'rtr/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('compliance-docs').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(
          contentType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
          upsert: true,
        ),
      );

      await supabase.from('tenancies').update({
        'rtr_document_url': path,
        'rtr_tenant_doc_type': _selectedDocType,
      }).eq('id', widget.tenancy.id);

      ref.invalidate(tenantTenanciesProvider);
      if (mounted) {
        setState(() { _showPicker = false; _uploading = false; });
        showAbodeToast(context, 'Document uploaded — your landlord will be notified');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        showAbodeToast(context, 'Upload failed: $e', isError: true);
      }
    }
  }
}

// ─── Overview sidebar tenancy card (compact) ─────────────────────────────────
class _OverviewTenancyCard extends StatelessWidget {
  final Tenancy tenancy;
  const _OverviewTenancyCard({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final p   = AbodePalette.of(context);
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    final t   = tenancy;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
        boxShadow: p.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.home_outlined, color: _accent, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.addressLine1,
                style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(t.postcode, style: TextStyle(color: p.sub, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(t.status, p).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
            child: Text(_humaniseStatus(t.status),
                style: TextStyle(color: _statusColor(t.status, p),
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
        ]),
        const SizedBox(height: 12),
        Divider(color: p.border, height: 1),
        const SizedBox(height: 10),
        if (t.landlord?.fullName != null) _Row(p: p,
            icon: Icons.person_outline, text: 'Landlord: ${t.landlord!.fullName}'),
        if (t.monthlyRent != null) _Row(p: p,
            icon: Icons.payments_outlined, text: '${fmt.format(t.monthlyRent!)}/month'),
        if ((t.depositAmount ?? 0) > 0) _Row(p: p,
            icon: Icons.account_balance_outlined,
            text: t.depositRef != null && t.depositRef!.isNotEmpty
                ? 'Deposit protected · ${t.depositScheme ?? "DPS"}'
                : 'Deposit: ${fmt.format(t.depositAmount)} (not yet protected)'),
        if (t.startDate != null && t.endDate != null) _Row(p: p,
            icon: Icons.calendar_today_outlined,
            text: '${t.startDate!.day}/${t.startDate!.month}/${t.startDate!.year}'
                ' · To ${t.endDate!.day}/${t.endDate!.month}/${t.endDate!.year}'),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final AbodePalette p;
  final IconData icon;
  final String text;
  const _Row({required this.p, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      Icon(icon, size: 13, color: p.muted),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: TextStyle(color: p.sub, fontSize: 12),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Notice served banner (RRA-compliant — no S21 language) ──────────────────
class _Section21Banner extends StatelessWidget {
  final Tenancy tenancy;
  const _Section21Banner({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final p        = AbodePalette.of(context);
    final vacate   = tenancy.expectedVacateDate;
    final daysLeft = vacate != null
        ? vacate.difference(DateTime.now()).inDays
        : null;
    final color = (daysLeft != null && daysLeft <= 30) ? p.red : p.amber;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.gavel_outlined, color: color, size: 16),
          const SizedBox(width: 7),
          Text('Notice to Vacate Served',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        if (tenancy.noticeServedDate != null)
          Text(
            'Served on: ${tenancy.noticeServedDate!.day}/${tenancy.noticeServedDate!.month}/${tenancy.noticeServedDate!.year}',
            style: TextStyle(color: p.sub, fontSize: 12),
          ),
        if (vacate != null) ...[
          const SizedBox(height: 3),
          Text(
            daysLeft != null && daysLeft > 0
                ? 'Landlord has requested you vacate by ${vacate.day}/${vacate.month}/${vacate.year} ($daysLeft days)'
                : 'Requested vacate date has passed (${vacate.day}/${vacate.month}/${vacate.year})',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Under the Renters\' Rights Act you cannot be evicted without a court order. '
          'For free advice contact Citizens Advice or Shelter UK.',
          style: TextStyle(color: p.sub, fontSize: 11, height: 1.4),
        ),
      ]),
    );
  }
}

// ─── Maintenance tab ──────────────────────────────────────────────────────────
class _MaintenanceContent extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _MaintenanceContent({required this.profile});

  @override
  ConsumerState<_MaintenanceContent> createState() =>
      _MaintenanceContentState();
}

class _MaintenanceContentState extends ConsumerState<_MaintenanceContent> {
  bool _archive = false;

  @override
  Widget build(BuildContext context) {
    final incidentsAsync  = ref.watch(tenantIncidentsProvider);
    final tenanciesAsync  = ref.watch(tenantTenanciesProvider);
    final activeTenancies = tenanciesAsync.valueOrNull
            ?.where((t) => t.status == 'active')
            .toList() ??
        [];
    final p = AbodePalette.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    return RefreshIndicator(
      color: _accent,
      onRefresh: () async => ref.invalidate(tenantIncidentsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(children: [
            Text('Maintenance',
              style: TextStyle(
                color: p.text, fontSize: 22,
                fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const Spacer(),
            if (activeTenancies.isNotEmpty && !_archive) ...[
              GestureDetector(
                onTap: () => showCreateIncidentSheet(context,
                    activeTenancies: activeTenancies),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(10)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 5),
                    Text('Report',
                      style: TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
            AbodeSegmentedControl(
              left: 'Open',
              right: 'Done',
              showLeft: !_archive,
              onLeft:  () => setState(() => _archive = false),
              onRight: () => setState(() => _archive = true),
            ),
          ]),
        ),

        Expanded(
          child: incidentsAsync.when(
            loading: () => const SkeletonIncidentList(),
            error: (_, __) => _emptyState(context, 'Could not load',
                icon: Icons.error_outline),
            data: (all) {
              final list = all
                  .where((i) => _archive
                      ? i.status == 'completed'
                      : i.status != 'completed')
                  .toList();
              if (list.isEmpty) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _accent.withValues(alpha: 0.2))),
                      child: Icon(
                        _archive ? Icons.history_rounded : Icons.check_rounded,
                        color: _accent, size: 34)),
                    const SizedBox(height: 18),
                    Text(
                      _archive ? 'No history yet' : 'All clear',
                      style: TextStyle(
                        color: p.text, fontSize: 18,
                        fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    const SizedBox(height: 6),
                    Text(
                      _archive
                          ? 'Completed issues will appear here'
                          : 'No open maintenance issues',
                      style: TextStyle(color: p.muted, fontSize: 14),
                      textAlign: TextAlign.center),
                  ]),
                ));
              }

              if (isDesktop) {
                return LayoutBuilder(builder: (_, constraints) {
                  final colW = (constraints.maxWidth - 52) / 2;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Wrap(
                      spacing: 12, runSpacing: 12,
                      children: list.map((inc) => SizedBox(
                        width: colW,
                        child: IncidentCard(
                          incident: inc,
                          role: 'tenant',
                          currentUserId: supabase.auth.currentUser?.id ?? '',
                          onAction: (action) async {
                            if (action == 'tenant_complete') {
                              final fullyDone = await ref
                                  .read(tenantMarkCompleteProvider.notifier)
                                  .markComplete(inc.id);
                              if (fullyDone &&
                                  inc.contractorId != null &&
                                  context.mounted) {
                                await showRateJobSheet(context,
                                    incidentId: inc.id,
                                    contractorId: inc.contractorId!,
                                    contractorName: inc.contractorName ?? 'Contractor');
                              }
                            } else if (action == 'confirm_visit') {
                              if (context.mounted) {
                                showTenantVisitConfirmSheet(context, incident: inc);
                              }
                            } else if (action == 'review_quote') {
                              if (context.mounted) {
                                showQuoteReviewSheet(context, incident: inc);
                              }
                            }
                          },
                          onViewThread: () => showIncidentCommentsSheet(context,
                              incidentId: inc.id,
                              incidentTitle: inc.title,
                              role: 'tenant'),
                        ),
                      )).toList(),
                    ),
                  );
                });
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => IncidentCard(
                  incident: list[i],
                  role: 'tenant',
                  currentUserId: supabase.auth.currentUser?.id ?? '',
                  onAction: (action) async {
                    if (action == 'tenant_complete') {
                      final fullyDone = await ref
                          .read(tenantMarkCompleteProvider.notifier)
                          .markComplete(list[i].id);
                      if (fullyDone &&
                          list[i].contractorId != null &&
                          context.mounted) {
                        await showRateJobSheet(context,
                            incidentId: list[i].id,
                            contractorId: list[i].contractorId!,
                            contractorName: list[i].contractorName ?? 'Contractor');
                      }
                    } else if (action == 'confirm_visit') {
                      if (context.mounted) {
                        showTenantVisitConfirmSheet(context, incident: list[i]);
                      }
                    } else if (action == 'review_quote') {
                      if (context.mounted) {
                        showQuoteReviewSheet(context, incident: list[i]);
                      }
                    }
                  },
                  onViewThread: () => showIncidentCommentsSheet(context,
                      incidentId: list[i].id,
                      incidentTitle: list[i].title,
                      role: 'tenant'),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── Documents tab ────────────────────────────────────────────────────────────
class _DocumentsContent extends ConsumerWidget {
  const _DocumentsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p            = AbodePalette.of(context);
    final tenanciesAsync = ref.watch(tenantTenanciesProvider);
    return RefreshIndicator(
      color: _accent,
      onRefresh: () async => ref.invalidate(tenantTenanciesProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(context, 'My Documents'),
        Expanded(
          child: tenanciesAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: _accent, strokeWidth: 2)),
            error: (_, __) => _emptyState(context, 'Could not load',
                icon: Icons.error_outline),
            data: (list) {
              final active =
                  list.where((t) => t.status == 'active').toList();
              if (active.isEmpty) {
                return _emptyState(context, 'No active tenancy.',
                    icon: Icons.folder_outlined);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                itemCount: active.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => Container(
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.border),
                    boxShadow: p.cardShadow,
                  ),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.home_outlined,
                              color: _accent, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(active[i].addressLine1,
                                  style: TextStyle(
                                      color: p.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(active[i].postcode,
                                  style: TextStyle(
                                      color: p.sub, fontSize: 12)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: ComplianceDocsPanel(
                          tenancyId: active[i].tenancyId,
                          canUpload: false),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
