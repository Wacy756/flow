import 'package:flow_app/core/widgets/abode_date_picker.dart';
import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/compliance_docs_panel.dart';
import '../widgets/create_incident_sheet.dart';
import '../widgets/rent_ledger_sheet.dart';
import '../widgets/holding_deposit_sheet.dart';
import '../widgets/deposit_dispute_sheet.dart';
import '../widgets/incident_card.dart';
import '../widgets/incident_comments_sheet.dart';
import '../widgets/rate_job_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/tenant_rights_sheet.dart';
import '../screens/messaging_screen.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Status helpers ───────────────────────────────────────────────────────────
String _humaniseTenancyStatus(String status) => switch (status.toLowerCase()) {
  'active'     => 'Active',
  'pending'    => 'Pending',
  'terminated' => 'Ended',
  'expired'    => 'Expired',
  'cancelled'  => 'Cancelled',
  _            => status[0].toUpperCase() + status.substring(1),
};

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
  AbodePalette get p => AbodePalette.of(context);

  _TTab _tab = _TTab.overview;
  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  @override
  Widget build(BuildContext context) =>
      _isMobile ? _buildMobile() : _buildDesktop();

  Widget _buildDesktop() {    return Material(
      color: p.bg,
      child: Row(children: [
        _Sidebar(
          profile:      widget.profile,
          activeTab:    _tab,
          onTabChange:  (t) => setState(() => _tab = t),
          onSignOut:    _signOut,
        ),
        Container(width: 1, color: p.border),
        Expanded(child: _buildContent()),
      ]),
    );
  }

  Widget _buildMobile() {    return Material(
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
  await showSignOutDialog(context, onSignOut);
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final UserProfile profile;
  final _TTab activeTab;
  final ValueChanged<_TTab> onTabChange;
  final VoidCallback onSignOut;
  const _Sidebar({
    required this.profile,
    required this.activeTab,
    required this.onTabChange,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final initials = profile.fullName.isNotEmpty
        ? profile.fullName
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';
    return Container(
      width: 224,
      color: p.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
            child: Row(children: [
              abodeLogo(),
              const SizedBox(width: 10),
              Text('Abode',
                  style: TextStyle(
                      color: p.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.3)),
            ]),
          ),
          const SizedBox(height: 10),
          // Role badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withValues(alpha: 0.35)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_outline, size: 12, color: _accent),
                SizedBox(width: 5),
                Text('TENANT',
                    style: TextStyle(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // Nav items
          for (final t in _TTab.values)
            _NavItem(
              tab:    t,
              active: activeTab == t,
              onTap:  () => onTabChange(t),
            ),
          const Spacer(),
          Container(height: 1, color: p.border),
          // User row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(initials,
                      style: const TextStyle(
                          color: _accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('Tenant',
                        style: TextStyle(color: p.sub, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _confirmSignOut(context, onSignOut),
                child: Icon(Icons.logout_outlined,
                    color: p.muted, size: 18),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final _TTab tab;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  AbodePalette get p => AbodePalette.of(context);

  bool _hover = false;
  static const _labels = {
    _TTab.overview:    'Overview',
    _TTab.home:        'My Home',
    _TTab.maintenance: 'Maintenance',
    _TTab.documents:   'Documents',
    _TTab.messages:    'Messages',
  };
  static const _icons = {
    _TTab.overview:    Icons.grid_view_rounded,
    _TTab.home:        Icons.home_outlined,
    _TTab.maintenance: Icons.build_outlined,
    _TTab.documents:   Icons.folder_outlined,
    _TTab.messages:    Icons.chat_bubble_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);    final a = widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin:  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: a
                ? _accent.withValues(alpha: 0.15)
                : _hover ? p.card : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(_icons[widget.tab]!, size: 18,
                color: a ? _accent : p.sub),
            const SizedBox(width: 10),
            Text(_labels[widget.tab]!,
                style: TextStyle(
                    color: a ? _accent : p.sub,
                    fontSize: 14,
                    fontWeight:
                        a ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

// ─── Mobile header ────────────────────────────────────────────────────────────
class _MobileHeader extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onSignOut;
  const _MobileHeader({required this.profile, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
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
        GestureDetector(
          onTap: () => showSettingsSheet(context,
              role: 'tenant', accent: _accent, onSignOut: onSignOut),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.border),
            ),
            child: Icon(Icons.settings_outlined, color: p.sub, size: 18),
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
    _TTab.maintenance: 'Issues',
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
// Shows DB-backed TenantRentCard when a schedule exists, else falls back to computed countdown
class _RentSection extends ConsumerWidget {
  final Tenancy tenancy;
  const _RentSection({required this.tenancy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(rentPaymentsProvider(tenancy.tenancyId));
    final payments = paymentsAsync.valueOrNull ?? [];
    if (payments.isNotEmpty) {
      return TenantRentCard(tenancy: tenancy);
    }
    if (tenancy.monthlyRent != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: _RentCountdownCard(tenancy: tenancy),
      );
    }
    return const SizedBox.shrink();
  }
}

class _RentCountdownCard extends StatelessWidget {
  final Tenancy tenancy;
  const _RentCountdownCard({required this.tenancy});

  DateTime _nextRentDate() {
    final now      = DateTime.now();
    final startDay = tenancy.startDate?.day ?? 1;
    var candidate  = DateTime(now.year, now.month, startDay);
    if (candidate.isBefore(now)) {
      candidate = DateTime(now.year, now.month + 1, startDay);
    }
    return candidate;
  }

  @override
  Widget build(BuildContext context) {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: p.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.payments_outlined, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Next rent: ${fmt.format(rent)}',
                  style: TextStyle(
                      color: p.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text(
                'Due ${nextDue.day}/${nextDue.month}/${nextDue.year}'
                ' · ${daysLeft == 0 ? "Today!" : daysLeft == 1 ? "Tomorrow" : "in $daysLeft days"}',
                style: TextStyle(color: color, fontSize: 12),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              daysLeft == 0 ? 'Today' : '$daysLeft days',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        if (hasEndDate && progress != null && daysUntilEnd != null && daysUntilEnd >= 0) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tenancy progress',
                  style: TextStyle(color: p.sub, fontSize: 11)),
              Text(
                daysUntilEnd > 0
                    ? '$daysUntilEnd days remaining'
                    : 'Ends today',
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
              valueColor:
                  AlwaysStoppedAnimation(daysUntilEnd <= 60 ? p.amber : _accent),
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
    final pending      = tenancies.where((t) =>
        t.status == 'pending' || t.status == 'offer_submitted').toList();
    final openIssues   = incidents.where((i) => i.status != 'completed').length;

    return RefreshIndicator(
      color: _accent,
      onRefresh: () async {
        ref.invalidate(tenantTenanciesProvider);
        ref.invalidate(tenantIncidentsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Welcome banner
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.home_outlined, color: _accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hi, ${profile.fullName.split(' ').first}!',
                      style: TextStyle(
                          color: p.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text(
                    active.isNotEmpty
                        ? active.first.addressLine1
                        : 'No active tenancy',
                    style: TextStyle(color: p.sub, fontSize: 13),
                  ),
                ]),
              ),
            ]),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _StatTile(
                value: '${active.length}',
                label: 'Active',
                icon: Icons.home_outlined,
                color: _accent,
                onTap: onGoToHome,
              ),
              const SizedBox(width: 10),
              _StatTile(
                value: '$openIssues',
                label: 'Open Issues',
                icon: Icons.build_outlined,
                color: openIssues > 0 ? p.amber : p.green,
                onTap: onGoToMaintenance,
              ),
            ]),
          ),

          // Rent section — DB schedule if exists, otherwise computed countdown
          if (active.isNotEmpty)
            _RentSection(tenancy: active.first),

          // Holding deposit cards for active tenancies
          ...active
              .where((t) =>
                  t.holdingDepositStatus != 'not_requested' &&
                  t.holdingDepositStatus != 'received')
              .map((t) => HoldingDepositCard(
                    tenancy: t,
                    landlordBankName:    t.landlord?.bankAccountName,
                    landlordSortCode:    t.landlord?.bankSortCode,
                    landlordAccountNumber: t.landlord?.bankAccountNumber,
                  )),

          // Pending invitations & submitted offers
          if (pending.isNotEmpty) ...[
            _sectionHeader(context, 'Pending Invitations'),
            ...pending.map((t) => _InvitationCard(tenancy: t, ref: ref)),
          ],

          // Recent issues
          _sectionHeader(context, 'Recent Issues',
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
            loading: () => const SizedBox(
              height: 210,
              child: ListSkeleton(itemCount: 2),
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
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: IncidentCard(
                            incident: i,
                            role: 'tenant',
                            currentUserId:
                                supabase.auth.currentUser?.id ?? '',
                            onAction: (action) async {
                              if (action == 'tenant_complete') {
                                await ref
                                    .read(tenantMarkCompleteProvider
                                        .notifier)
                                    .markComplete(i.id);
                                if (i.contractorId != null &&
                                    context.mounted) {
                                  await showRateJobSheet(context,
                                      incidentId: i.id,
                                      contractorId: i.contractorId!,
                                      contractorName:
                                          i.contractorName ?? 'Contractor');
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

          // My home preview
          _sectionHeader(context, 'My Home'),
          tenanciesAsync.when(
            loading: () => const SizedBox(
              height: 180,
              child: ListSkeleton(itemCount: 1),
            ),
            error: (_, __) =>
                _emptyState(context, 'Could not load',
                    icon: Icons.error_outline),
            data: (list) {
              if (active.isEmpty) {
                return _emptyState(context, 'No active tenancy yet.',
                    icon: Icons.home_outlined);
              }
              return Column(
                children: active
                    .take(1)
                    .map((t) => Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: _TenancyInfoCard(tenancy: t),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

// ─── Stat tile ────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
            boxShadow: p.cardShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            Text(label, style: TextStyle(color: p.sub, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

// ─── Invitation card ──────────────────────────────────────────────────────────
// ─── Invitation card — pending (fill in) or offer_submitted (awaiting review) ──
class _InvitationCard extends StatelessWidget {
  final Tenancy tenancy;
  final WidgetRef ref;
  const _InvitationCard({required this.tenancy, required this.ref});

  bool get _submitted => tenancy.status == 'offer_submitted';

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _submitted
              ? p.green.withValues(alpha: 0.4)
              : _accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_submitted ? p.green : _accent).withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: (_submitted ? p.green : _accent).withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: (_submitted ? p.green : _accent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _submitted ? Icons.check_circle_outline : Icons.mail_outline,
                  color: _submitted ? p.green : _accent,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _submitted ? 'Application Submitted' : 'Tenancy Invite',
                      style: TextStyle(
                          color: _submitted ? p.green : _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3),
                    ),
                    if (tenancy.landlord?.fullName != null)
                      Text('From ${tenancy.landlord!.fullName}',
                          style: TextStyle(color: p.sub, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (_submitted ? p.green : p.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _submitted ? 'UNDER REVIEW' : 'ACTION NEEDED',
                  style: TextStyle(
                      color: _submitted ? p.green : p.amber,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4),
                ),
              ),
            ]),
          ),

          // ── Property + asking terms ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenancy.shortAddress,
                    style: TextStyle(
                        color: p.text, fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(children: [
                  if (tenancy.monthlyRent != null) ...[
                    _OfferDetail(
                      icon: Icons.payments_outlined,
                      label: 'Asking rent',
                      value: '£${tenancy.monthlyRent!.toStringAsFixed(0)}/mo',
                      p: p,
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (tenancy.depositAmount != null)
                    _OfferDetail(
                      icon: Icons.account_balance_outlined,
                      label: 'Deposit',
                      value: '£${tenancy.depositAmount!.toStringAsFixed(0)}',
                      p: p,
                    ),
                ]),

                // If submitted, show tenant's submitted details
                if (_submitted) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: p.border),
                  const SizedBox(height: 10),
                  if (tenancy.tenantEmploymentStatus != null)
                    _OfferDetail(
                      icon: Icons.work_outline_rounded,
                      label: 'Your employment',
                      value: _employmentLabel(tenancy.tenantEmploymentStatus!),
                      p: p,
                    ),
                  if (tenancy.tenantAnnualIncome != null) ...[
                    const SizedBox(height: 6),
                    _OfferDetail(
                      icon: Icons.bar_chart_rounded,
                      label: 'Annual income',
                      value: '£${tenancy.tenantAnnualIncome!.toStringAsFixed(0)}',
                      p: p,
                    ),
                  ],
                  if (tenancy.tenantMoveInPreference != null) ...[
                    const SizedBox(height: 6),
                    _OfferDetail(
                      icon: Icons.calendar_today_outlined,
                      label: 'Preferred move-in',
                      value: DateFormat('d MMM yyyy').format(tenancy.tenantMoveInPreference!),
                      p: p,
                    ),
                  ],
                ],
              ],
            ),
          ),

          if (_submitted)
            // Submitted state — waiting note
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.border),
                ),
                child: Row(children: [
                  Icon(Icons.hourglass_top_rounded, size: 13, color: p.muted),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Your application is with the landlord. You\'ll be notified once they\'ve made a decision.',
                      style: TextStyle(color: p.muted, fontSize: 11, height: 1.4),
                    ),
                  ),
                ]),
              ),
            )
          else
            // Pending state — CTA to complete application + decline
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // Info note
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 13, color: p.muted),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Fill in your application details — employment, income, and your preferred move-in date.',
                          style: TextStyle(color: p.muted, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    // Decline
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _confirmDecline(context),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: p.border),
                          ),
                          alignment: Alignment.center,
                          child: Text('Not interested',
                              style: TextStyle(
                                  color: p.sub, fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Complete application
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () => _showOfferForm(context),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(
                              color: _accent.withValues(alpha: 0.3),
                              blurRadius: 8, offset: const Offset(0, 2),
                            )],
                          ),
                          alignment: Alignment.center,
                          child: const Text('Complete application',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showOfferForm(BuildContext context) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TenantOfferForm(tenancy: tenancy, ref: ref),
    );
  }

  Future<void> _confirmDecline(BuildContext context) async {
    final p = AbodePalette.of(context);
    final confirmed = await showAbodeConfirmDialog(
      context,
      title: 'Not interested?',
      body: 'Remove this invite for ${tenancy.shortAddress}? This can\'t be undone.',
      confirmLabel: 'Remove',
      cancelLabel: 'Keep it',
      isDestructive: true,
      icon: Icons.close_rounded,
    ) ?? false;

    if (confirmed) {
      ref.read(acceptInvitationProvider.notifier).decline(tenancy.id);
    }
  }

  String _employmentLabel(String status) => switch (status) {
    'employed'      => 'Employed',
    'self_employed' => 'Self-employed',
    'student'       => 'Student',
    'unemployed'    => 'Unemployed',
    'retired'       => 'Retired',
    _               => status,
  };
}

// ─── Tenant offer / application form ──────────────────────────────────────────
class _TenantOfferForm extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  final WidgetRef ref;
  const _TenantOfferForm({required this.tenancy, required this.ref});

  @override
  ConsumerState<_TenantOfferForm> createState() => _TenantOfferFormState();
}

class _TenantOfferFormState extends ConsumerState<_TenantOfferForm> {
  AbodePalette get p => AbodePalette.of(context);

  String? _employment;
  final _incomeCtrl  = TextEditingController();
  final _messageCtrl = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text('Your application',
                    style: TextStyle(
                        color: p.text, fontSize: 20, fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text(widget.tenancy.shortAddress,
                    style: TextStyle(color: p.sub, fontSize: 13)),
                const SizedBox(height: 20),

                // Employment status
                _Label('EMPLOYMENT STATUS', p),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _employmentOptions.map((opt) {
                    final selected = _employment == opt.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _employment = opt.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected
                              ? _accent.withValues(alpha: 0.12)
                              : p.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? _accent : p.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(opt.$2,
                            style: TextStyle(
                                color: selected ? _accent : p.sub,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Annual income
                _Label('GROSS ANNUAL INCOME', p),
                const SizedBox(height: 6),
                _FormField(
                  controller: _incomeCtrl,
                  hint: '30000',
                  type: TextInputType.number,
                  prefix: '£',
                  p: p,
                ),
                const SizedBox(height: 16),

                // Preferred move-in
                _Label('PREFERRED MOVE-IN DATE', p),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: p.sub),
                      const SizedBox(width: 10),
                      Text(
                        _moveIn == null
                            ? 'Select date'
                            : DateFormat('d MMM yyyy').format(_moveIn!),
                        style: TextStyle(
                            color: _moveIn == null ? p.muted : p.text,
                            fontSize: 15),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Message to landlord (optional)
                _Label('MESSAGE TO LANDLORD (OPTIONAL)', p),
                const SizedBox(height: 6),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 3,
                  style: TextStyle(color: p.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Introduce yourself, explain your situation...',
                    hintStyle: TextStyle(color: p.muted, fontSize: 14),
                    filled: true,
                    fillColor: p.card,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: p.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: p.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _accent, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: GestureDetector(
                    onTap: _canSubmit ? _submit : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: _canSubmit ? _accent : p.border,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _canSubmit ? [BoxShadow(
                          color: _accent.withValues(alpha: 0.3),
                          blurRadius: 16, offset: const Offset(0, 4),
                        )] : null,
                      ),
                      alignment: Alignment.center,
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Submit application',
                              style: TextStyle(
                                  color: _canSubmit ? Colors.white : p.muted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSubmit =>
      _employment != null &&
      _incomeCtrl.text.trim().isNotEmpty &&
      _moveIn != null &&
      !_saving;

  Future<void> _pickDate() async {
    final picked = await showAbodeDatePicker(
      context,
      initialDate: DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _moveIn = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _saving = true);
    try {
      final income = double.tryParse(
          _incomeCtrl.text.trim().replaceAll(',', '')) ?? 0;

      final userId = supabase.auth.currentUser?.id;
      await supabase.from('tenancies').update({
        'status': 'offer_submitted',
        'tenant_employment_status': _employment,
        'tenant_annual_income': income,
        'tenant_move_in_preference': _moveIn!.toIso8601String(),
        if (_messageCtrl.text.trim().isNotEmpty)
          'tenant_message': _messageCtrl.text.trim(),
        'offer_submitted_at': DateTime.now().toIso8601String(),
        // Claim the tenancy — set real tenant_id and clear the invite email
        if (userId != null) 'tenant_id': userId,
        'invited_email': null,
      }).eq('id', widget.tenancy.id);

      widget.ref.invalidate(tenantTenanciesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        showAbodeToast(context, 'Application submitted — the landlord will be in touch');
      }
    } catch (_) {
      setState(() => _saving = false);
    }
  }
}

// ─── Shared helpers ────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final AbodePalette p;
  const _Label(this.text, this.p);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            color: AbodePalette.of(context).sub,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4));
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? type;
  final String? prefix;
  final AbodePalette p;
  const _FormField({
    required this.controller,
    required this.hint,
    required this.p,
    this.type,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final pal = AbodePalette.of(context);
    return TextField(
      controller: controller,
      keyboardType: type,
      style: TextStyle(color: pal.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: pal.muted, fontSize: 15),
        prefixText: prefix,
        prefixStyle: TextStyle(color: pal.sub, fontSize: 15),
        filled: true,
        fillColor: pal.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: pal.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: pal.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 2)),
      ),
    );
  }
}

class _OfferDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AbodePalette p;
  const _OfferDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: p.muted),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: p.muted, fontSize: 10)),
        Text(value,
            style: TextStyle(
                color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ]);
  }
}

// ─── Home tab ─────────────────────────────────────────────────────────────────
class _HomeContent extends ConsumerWidget {
  final UserProfile profile;
  const _HomeContent({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p            = AbodePalette.of(context);
    final tenanciesAsync = ref.watch(tenantTenanciesProvider);
    return RefreshIndicator(
      color: _accent,
      onRefresh: () async => ref.invalidate(tenantTenanciesProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(context, 'My Home'),
        Expanded(
          child: tenanciesAsync.when(
            loading: () => const ListSkeleton(),
            error: (_, __) =>
                _emptyState(context, 'Could not load',
                    icon: Icons.error_outline),
            data: (list) {
              final active =
                  list.where((t) => t.status == 'active').toList();
              if (active.isEmpty) {
                return _emptyState(context, 'No active tenancy yet.',
                    icon: Icons.home_outlined);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                itemCount: active.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final t = active[i];
                  final hasReview = t.nextRentReviewDate != null &&
                      t.nextRentReviewDate!
                              .difference(DateTime.now())
                              .inDays <=
                          60 &&
                      t.nextRentReviewDate!.isAfter(DateTime.now());
                  final hasDeposit = (t.depositAmount ?? 0) > 0;
                  return Column(children: [
                    if (hasReview)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: p.amber.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: p.amber.withValues(alpha: 0.25)),
                        ),
                        child: Row(children: [
                          Icon(Icons.event_note_outlined,
                              color: p.amber, size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rent review due '
                              '${t.nextRentReviewDate!.day}/${t.nextRentReviewDate!.month}/${t.nextRentReviewDate!.year}'
                              ' (${t.nextRentReviewDate!.difference(DateTime.now()).inDays} days)',
                              style: TextStyle(
                                  color: p.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ),
                    _TenancyInfoCard(tenancy: t),
                    if (hasDeposit) ...[
                      const SizedBox(height: 6),
                      _DepositDisputeButton(tenancy: t),
                    ],
                    const SizedBox(height: 6),
                    const _KnowYourRightsButton(),
                  ]);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── Tenancy info card ────────────────────────────────────────────────────────
class _TenancyInfoCard extends StatelessWidget {
  final Tenancy tenancy;
  const _TenancyInfoCard({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final p   = AbodePalette.of(context);
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);
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
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.home_outlined, color: _accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tenancy.addressLine1,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(tenancy.postcode,
                  style: TextStyle(color: p.sub, fontSize: 12)),
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_humaniseTenancyStatus(tenancy.status),
                style: TextStyle(
                    color: tenancy.status.toLowerCase() == 'active'
                        ? p.green
                        : p.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
        ]),
        if (tenancy.landlord?.fullName != null) ...[
          const SizedBox(height: 12),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.person_outline, size: 14, color: p.muted),
            const SizedBox(width: 6),
            Text('Landlord: ${tenancy.landlord!.fullName}',
                style: TextStyle(color: p.sub, fontSize: 13)),
          ]),
        ],
        if (tenancy.monthlyRent != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.payments_outlined, size: 14, color: p.muted),
            const SizedBox(width: 6),
            Text('${fmt.format(tenancy.monthlyRent)}/month',
                style: TextStyle(color: p.sub, fontSize: 13)),
          ]),
        ],
        if ((tenancy.depositAmount ?? 0) > 0) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.account_balance_outlined,
                size: 14, color: p.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tenancy.depositRef != null && tenancy.depositRef!.isNotEmpty
                    ? 'Deposit protected: ${tenancy.depositScheme ?? "DPS"}'
                        ' · ${tenancy.depositRef}'
                    : 'Deposit: ${fmt.format(tenancy.depositAmount)} (not yet protected)',
                style: TextStyle(color: p.sub, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ],
        if (tenancy.startDate != null || tenancy.endDate != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.calendar_today_outlined,
                size: 14, color: p.muted),
            const SizedBox(width: 6),
            Text(
              [
                if (tenancy.startDate != null)
                  'From ${tenancy.startDate!.day}/${tenancy.startDate!.month}/${tenancy.startDate!.year}',
                if (tenancy.endDate != null)
                  'To ${tenancy.endDate!.day}/${tenancy.endDate!.month}/${tenancy.endDate!.year}',
              ].join(' · '),
              style: TextStyle(color: p.sub, fontSize: 13),
            ),
          ]),
        ],
        if (tenancy.noticeServedDate != null &&
            tenancy.noticeGivenBy == 'landlord') ...[
          const SizedBox(height: 12),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 12),
          _Section21Banner(tenancy: tenancy),
        ],
      ]),
    );
  }
}

// ─── Deposit dispute button ───────────────────────────────────────────────────
class _DepositDisputeButton extends StatelessWidget {
  final Tenancy tenancy;
  const _DepositDisputeButton({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: () => showDepositDisputeSheet(context, tenancy: tenancy),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.account_balance_outlined, size: 15, color: p.sub),
          const SizedBox(width: 7),
          Text('Deposit Dispute Helper',
              style: TextStyle(
                  color: p.sub,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─── Know Your Rights button ──────────────────────────────────────────────────
class _KnowYourRightsButton extends StatelessWidget {
  const _KnowYourRightsButton();

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: () => showTenantRightsSheet(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _accent.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.balance_outlined, size: 15, color: _accent),
            SizedBox(width: 7),
            Text('Know Your Rights',
                style: TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Section 21 / notice banner ───────────────────────────────────────────────
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
                ? 'You must vacate by ${vacate.day}/${vacate.month}/${vacate.year} ($daysLeft days)'
                : 'Vacate date has passed (${vacate.day}/${vacate.month}/${vacate.year})',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'If you believe this notice is invalid, seek independent advice from Citizens Advice or Shelter UK.',
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
    final p = AbodePalette.of(context);
    final incidentsAsync  = ref.watch(tenantIncidentsProvider);
    final tenanciesAsync  = ref.watch(tenantTenanciesProvider);
    final activeTenancies = tenanciesAsync.valueOrNull
            ?.where((t) => t.status == 'active')
            .toList() ??
        [];
    return RefreshIndicator(
      color: _accent,
      onRefresh: () async => ref.invalidate(tenantIncidentsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(
          context,
          _archive ? 'Previous Issues' : 'My Issues',
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            if (activeTenancies.isNotEmpty && !_archive)
              GestureDetector(
                onTap: () => showCreateIncidentSheet(context,
                    activeTenancies: activeTenancies),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Report',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => setState(() => _archive = !_archive),
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  _archive ? 'View active' : 'History',
                  style: const TextStyle(
                      color: _accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: incidentsAsync.when(
            loading: () => const ListSkeleton(),
            error: (_, __) => _emptyState(context, 'Could not load',
                icon: Icons.error_outline),
            data: (all) {
              final list = all
                  .where((i) => _archive
                      ? i.status == 'completed'
                      : i.status != 'completed')
                  .toList();
              if (list.isEmpty) {
                return _emptyState(
                  context,
                  _archive ? 'No previous issues' : 'No open issues.',
                  icon: _archive
                      ? Icons.history
                      : Icons.check_circle_outline,
                );
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
                      await ref
                          .read(tenantMarkCompleteProvider.notifier)
                          .markComplete(list[i].id);
                      if (list[i].contractorId != null &&
                          context.mounted) {
                        await showRateJobSheet(context,
                            incidentId: list[i].id,
                            contractorId: list[i].contractorId!,
                            contractorName:
                                list[i].contractorName ?? 'Contractor');
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
    final p = AbodePalette.of(context);
    final tenanciesAsync = ref.watch(tenantTenanciesProvider);

    return tenanciesAsync.when(
      loading: () => const ListSkeleton(),
      error: (_, __) => _emptyState(context, 'Could not load documents',
          icon: Icons.error_outline),
      data: (list) {
        final active = list.where((t) => t.status == 'active').toList();

        if (active.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context, 'My Documents'),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: p.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.border),
                        ),
                        child: Icon(Icons.folder_open_outlined,
                            size: 32, color: p.muted),
                      ),
                      const SizedBox(height: 16),
                      Text('No documents yet',
                          style: TextStyle(
                              color: p.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Documents will appear here once your\ntenancy is active.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.sub, fontSize: 13, height: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Single active tenancy — show full doc view
        final tenancy = active.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'My Documents'),
            Expanded(
              child: TenantDocumentsView(
                tenancyId: tenancy.tenancyId,
                propertyAddress: tenancy.addressLine1,
                postcode: tenancy.postcode,
              ),
            ),
          ],
        );
      },
    );
  }
}
// ── Entry point for agent welcome pack ───────────────────────────────────────

void showWelcomePackSheet(BuildContext context) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WelcomePackPlaceholder(),
  );
}

class _WelcomePackPlaceholder extends StatelessWidget {
  const _WelcomePackPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: const Center(child: Text('Welcome Pack')),
    );
  }
}
