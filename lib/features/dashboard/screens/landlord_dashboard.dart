import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/role_sidebar.dart';
import '../../../core/widgets/shimmer.dart';
import '../models/compliance_certificate.dart';
import '../models/incident.dart';
import '../models/property_record.dart';
import '../models/rent_payment.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import '../providers/messaging_providers.dart';
import '../widgets/add_tenancy_sheet.dart';
import '../widgets/add_property_sheet.dart';
import '../widgets/add_tenant_sheet.dart';
import '../widgets/landlord_onboarding_wizard.dart';
import '../widgets/dispute_detail_sheet.dart';
import '../widgets/job_review_sheet.dart';
import '../widgets/quote_review_sheet.dart';
import '../widgets/compliance_docs_panel.dart';
import '../widgets/incident_card.dart';
import '../widgets/incident_comments_sheet.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/pet_request_response_sheet.dart';
import '../widgets/rate_job_sheet.dart';
import '../widgets/section13_notice_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/tenancy_card.dart';
import '../widgets/tenancy_details_sheet.dart';
import 'check_in_report_screen.dart';
import 'landlord_compliance_screen.dart';
import 'messaging_screen.dart';

// ─── Role accent ──────────────────────────────────────────────────────────────
const _accent = Color(0xFF3B82F6);

// ─── Tabs ─────────────────────────────────────────────────────────────────────
enum _LTab { overview, properties, incidents, compliance, messages }

// ─── Root ─────────────────────────────────────────────────────────────────────
class LandlordDashboard extends ConsumerStatefulWidget {
  final UserProfile profile;
  const LandlordDashboard({super.key, required this.profile});

  @override
  ConsumerState<LandlordDashboard> createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends ConsumerState<LandlordDashboard> {
  _LTab _tab = _LTab.overview;

  bool get _isMobile => MediaQuery.of(context).size.width < 700;

  @override
  Widget build(BuildContext context) {
    ref.listen(deepLinkIncidentIdProvider, (_, id) {
      if (id != null) setState(() => _tab = _LTab.incidents);
    });
    ref.listen(deepLinkTenancyIdProvider, (_, id) {
      if (id != null) setState(() => _tab = _LTab.properties);
    });
    return _isMobile ? _buildMobile() : _buildDesktop();
  }

  Widget _buildDesktop() {
    final p = AbodePalette.of(context);
    return Material(
      color: p.bg,
      child: Row(
        children: [
          RoleSidebar<_LTab>(
            profile:     widget.profile,
            accent:      _accent,
            roleLabel:   'Landlord',
            tabs:        _LTab.values,
            activeTab:   _tab,
            onTabChange: (t) => setState(() => _tab = t),
            labelOf:     (t) => switch (t) {
              _LTab.overview    => 'Overview',
              _LTab.properties  => 'Properties',
              _LTab.incidents   => 'Maintenance',
              _LTab.compliance  => 'Compliance',
              _LTab.messages    => 'Messages',
            },
            iconOf:      (t) => switch (t) {
              _LTab.overview    => Icons.grid_view_rounded,
              _LTab.properties  => Icons.home_work_outlined,
              _LTab.incidents   => Icons.build_outlined,
              _LTab.compliance  => Icons.verified_user_outlined,
              _LTab.messages    => Icons.chat_bubble_outline_rounded,
            },
            onSignOut:        _signOut,
            onNotifications:  () => showNotificationsSheet(context),
            onSettings:       () => showSettingsSheet(context,
                role: 'landlord', accent: _accent, onSignOut: _signOut),
          ),
          Expanded(child: _buildContent()),
          Container(width: 1, color: p.border),
          SizedBox(
            width: 284,
            child: _ActionCenterSidebar(
              onGoToTab: (t) => setState(() => _tab = t),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    final p = AbodePalette.of(context);
    return Material(
      color: p.bg,
      child: SafeArea(bottom: false, child: Column(
        children: [
          _MobileHeader(profile: widget.profile, onSignOut: _signOut),
          Expanded(child: _buildContent()),
          _MobileBottomNav(activeTab: _tab, onTabChange: (t) => setState(() => _tab = t)),
        ],
      )),
    );
  }

  Widget _buildContent() => switch (_tab) {
    _LTab.overview    => _OverviewContent(profile: widget.profile,
        onGoToProperties: () => setState(() => _tab = _LTab.properties),
        onGoToIncidents:  () => setState(() => _tab = _LTab.incidents),
        onGoToCompliance: () => setState(() => _tab = _LTab.compliance),
        onGoToMessages:   () => setState(() => _tab = _LTab.messages)),
    _LTab.properties  => _PropertiesContent(profile: widget.profile),
    _LTab.incidents   => _IncidentsContent(),
    _LTab.compliance  => const LandlordComplianceScreen(),
    _LTab.messages    => const MessagingScreen(role: 'landlord'),
  };

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) context.go(AppRoutes.landing);
  }
}

// ─── Mobile header ────────────────────────────────────────────────────────────
class _MobileHeader extends ConsumerWidget {
  final UserProfile profile;
  final VoidCallback onSignOut;
  const _MobileHeader({required this.profile, required this.onSignOut});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final firstName = profile.fullName.split(' ').first;
    final unread = ref.watch(unreadNotificationCountProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      color: p.bg,
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting(),
            style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.1)),
          const SizedBox(height: 1),
          Text(firstName,
            style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        ])),
        // Notification bell
        GestureDetector(
          onTap: () => showNotificationsSheet(context),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(12),
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
                    style: const TextStyle(color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        // Settings
        GestureDetector(
          onTap: () => context.push(AppRoutes.settings),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(12),
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
  final _LTab activeTab;
  final ValueChanged<_LTab> onTabChange;
  const _MobileBottomNav({required this.activeTab, required this.onTabChange});
  static const _mobileIcons  = {_LTab.overview:Icons.grid_view_rounded,_LTab.properties:Icons.home_work_outlined,_LTab.incidents:Icons.build_outlined,_LTab.compliance:Icons.verified_user_outlined,_LTab.messages:Icons.chat_bubble_outline_rounded};
  static const _mobileLabels = {_LTab.overview:'Overview',_LTab.properties:'Properties',_LTab.incidents:'Maintenance',_LTab.compliance:'Compliance',_LTab.messages:'Messages'};
  static const _mobileTabs   = [_LTab.overview,_LTab.properties,_LTab.incidents,_LTab.compliance,_LTab.messages];

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: _mobileTabs.map((t) {
              final a = t == activeTab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTabChange(t),
                  behavior: HitTestBehavior.opaque,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Pill indicator above icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: a ? 20 : 0,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 5),
                      decoration: BoxDecoration(
                        color: a ? p.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Icon(_mobileIcons[t]!, size: 22,
                      color: a ? Colors.white : p.muted),
                    const SizedBox(height: 3),
                    Text(_mobileLabels[t]!,
                      style: TextStyle(
                        fontSize: 10,
                        color: a ? Colors.white : p.muted,
                        fontWeight: a ? FontWeight.w600 : FontWeight.w400,
                      )),
                  ]),
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
Widget _emptyState(
  BuildContext context,
  String msg, {
  required IconData icon,
  VoidCallback? onRetry,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final p = AbodePalette.of(context);
  final isError = onRetry != null;
  final color   = isError ? p.red : p.muted;
  return Center(
    child: Padding(padding: const EdgeInsets.all(48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(
            color: isError ? p.red.withValues(alpha: 0.08) : p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isError ? p.red.withValues(alpha: 0.2) : p.border)),
          child: Icon(icon, color: color, size: 26)),
        const SizedBox(height: 16),
        Text(msg, textAlign: TextAlign.center,
          style: TextStyle(color: p.sub, fontSize: 14, height: 1.5)),
        if (onRetry != null) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh_rounded, size: 14, color: p.sub),
                const SizedBox(width: 6),
                Text('Try again', style: TextStyle(color: p.sub, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: p.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.green.withValues(alpha: 0.25))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 14, color: p.green),
                const SizedBox(width: 6),
                Text(actionLabel, style: TextStyle(color: p.green, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      ]),
    ),
  );
}

// ─── Onboarding banner (shown when 0 properties) ─────────────────────────────
class _OnboardingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: () => showLandlordOnboardingWizard(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accent.withValues(alpha: 0.12), _accent.withValues(alpha: 0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.home_work_outlined, color: _accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Set up your first property',
              style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
            const SizedBox(height: 2),
            Text('Add a property, then invite your tenant — takes 2 minutes',
              style: TextStyle(color: p.sub, fontSize: 12, height: 1.4)),
          ])),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Start',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

Widget _sectionHeader(BuildContext context, String title, {Widget? action}) {
  final p = AbodePalette.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    child: Row(children: [
      Expanded(child: Text(title, style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
      if (action != null) action,
    ]),
  );
}

// ─── Overview ("Today" brief) ─────────────────────────────────────────────────
class _OverviewContent extends ConsumerWidget {
  final UserProfile profile;
  final VoidCallback onGoToProperties;
  final VoidCallback onGoToIncidents;
  final VoidCallback onGoToCompliance;
  final VoidCallback onGoToMessages;
  const _OverviewContent({required this.profile, required this.onGoToProperties, required this.onGoToIncidents, required this.onGoToCompliance, required this.onGoToMessages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final tenanciesAsync   = ref.watch(landlordTenanciesProvider);
    final propertiesAsync  = ref.watch(landlordPropertiesProvider);
    final incidentsAsync   = ref.watch(landlordIncidentsProvider);
    final complianceAsync  = ref.watch(complianceSummaryProvider);
    final petRequestsAsync = ref.watch(landlordPetRequestsProvider);

    final tenancies     = tenanciesAsync.valueOrNull ?? [];
    final propCount     = propertiesAsync.valueOrNull?.length ?? tenancies.length;
    final incidents     = incidentsAsync.valueOrNull ?? [];
    final openCount     = incidents.where((i) => i.status != 'completed').length;
    final totalTenants  = tenancies.fold<int>(0, (s, t) => s + t.tenants.length);
    final activeCount   = tenancies.where((t) => t.status == 'active').length;
    final monthlyIncome = tenancies.where((t) => t.status == 'active').fold<double>(0, (s, t) => s + (t.monthlyRent ?? 0));
    final complianceOk  = complianceAsync.valueOrNull?.hasAlerts != true;

    final pendingPets = (petRequestsAsync.valueOrNull ?? [])
        .where((r) => r.isPending).toList()
      ..sort((a, b) => a.daysUntilDeadline.compareTo(b.daysUntilDeadline));

    final s13Due = tenancies.where((t) =>
        t.nextRentReviewDate != null &&
        t.nextRentReviewDate!.difference(DateTime.now()).inDays <= 60 &&
        t.nextRentReviewDate!.isAfter(DateTime.now())).toList();

    final hasActions = pendingPets.isNotEmpty || s13Due.isNotEmpty;

    List<Widget> buildActionItems() {
      if (!hasActions) return [];
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Text('Action needed',
              style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: p.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${pendingPets.length + s13Due.length}',
                style: TextStyle(color: p.red, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
        ),
        const SizedBox(height: 10),
        ...pendingPets.take(3).map((req) {
          final tenancy = tenancies.firstWhere(
            (t) => t.id == req.tenancyId || t.tenancyId == req.tenancyId,
            orElse: () => tenancies.isNotEmpty ? tenancies.first : Tenancy(
              id: '', tenancyId: '', status: 'active',
              addressLine1: 'Property', postcode: '', createdAt: DateTime.now(),
              referencingStatus: 'not_started', rtrStatus: 'not_started',
              holdingDepositStatus: 'not_requested',
            ),
          );
          final daysLeft = req.daysUntilDeadline;
          final color = req.isOverdue ? p.red : daysLeft <= 7 ? p.amber : p.sub;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: GestureDetector(
              onTap: () => showPetRequestResponseSheet(context, request: req, tenancy: tenancy),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                  boxShadow: p.cardShadow),
                child: Row(children: [
                  Text(req.petEmoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Pet request — ${req.petBreed.isNotEmpty ? req.petBreed : req.petType}',
                      style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(tenancy.shortAddress,
                      style: TextStyle(color: p.muted, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        req.isOverdue ? 'Overdue' : daysLeft == 0 ? 'Today' : '${daysLeft}d left',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 4),
                    Text('Tap to respond', style: TextStyle(color: p.muted, fontSize: 10)),
                  ]),
                ]),
              ),
            ),
          );
        }),
        ...s13Due.take(2).map((t) {
          final days = t.nextRentReviewDate!.difference(DateTime.now()).inDays;
          final color = days <= 14 ? p.amber : p.sub;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: GestureDetector(
              onTap: () => showSection13NoticeSheet(context, tenancy: t),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                  boxShadow: p.cardShadow),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.trending_up_rounded, size: 18, color: color)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Rent review due', style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(t.shortAddress, style: TextStyle(color: p.muted, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${days}d', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Serve S.13', style: TextStyle(color: p.muted, fontSize: 10)),
                  ]),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ];
    }

    final onboardingBanner = propCount == 0 && !propertiesAsync.isLoading
        ? [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _OnboardingBanner(),
            ),
            const SizedBox(height: 16),
          ]
        : <Widget>[];

    final heroAndStats = [
      _HeroCard(
        tenancies: tenancies,
        monthlyIncome: monthlyIncome,
        activeCount: activeCount,
        totalTenants: totalTenants,
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          Row(children: [
            _BentoStat(value: '$propCount', label: 'Properties', icon: Icons.home_work_outlined, color: _accent, onTap: onGoToProperties, p: p),
            const SizedBox(width: 10),
            _BentoStat(value: '$totalTenants', label: 'Tenants', icon: Icons.people_outline, color: p.green),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _BentoStat(value: '$openCount', label: 'Open issues', icon: Icons.build_outlined, color: openCount > 0 ? p.amber : p.green, onTap: openCount > 0 ? onGoToIncidents : null, p: p),
            const SizedBox(width: 10),
            _BentoStat(value: complianceOk ? '✓' : '!', label: 'Compliance', icon: complianceOk ? Icons.verified_user_outlined : Icons.warning_amber_rounded, color: complianceOk ? p.green : p.amber, onTap: onGoToCompliance, p: p),
          ]),
        ]),
      ),
      const SizedBox(height: 20),
      _QuickActions(
        onGoToIncidents: onGoToIncidents,
        onGoToProperties: onGoToProperties,
        onGoToCompliance: onGoToCompliance,
        onGoToMessages: onGoToMessages,
      ),
      const SizedBox(height: 16),
    ];

    final rightColumnContent = [
      _KeyDatesSection(tenancies: tenancies, onGoToProperties: onGoToProperties),
      _ActivityFeed(incidentsAsync: incidentsAsync, onGoToIncidents: onGoToIncidents, ref: ref),
      const SizedBox(height: 40),
    ];

    if (isDesktop) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...onboardingBanner,
            ...buildActionItems(),
            ...heroAndStats,
            ...rightColumnContent,
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: p.green,
      onRefresh: () async {
        ref.invalidate(landlordTenanciesProvider);
        ref.invalidate(landlordIncidentsProvider);
        ref.invalidate(complianceSummaryProvider);
        ref.invalidate(landlordPetRequestsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...onboardingBanner,
          ...buildActionItems(),
          ...heroAndStats,
          ...rightColumnContent,
        ]),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final BuildContext context;
  final String value, label; final IconData icon; final Color color; final VoidCallback? onTap;
  const _StatTile({required this.context, required this.value, required this.label, required this.icon, required this.color, this.onTap});
  @override
  Widget build(BuildContext ctx) {
    final p = AbodePalette.of(ctx);
    return Expanded(child: GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border), boxShadow: p.cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20), const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          Text(label, style: TextStyle(color: p.sub, fontSize: 11)),
        ]),
      ),
    ));
  }
}

// ─── Properties tab ───────────────────────────────────────────────────────────
class _PropertiesContent extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _PropertiesContent({required this.profile});
  @override
  ConsumerState<_PropertiesContent> createState() => _PropertiesContentState();
}

class _PropertiesContentState extends ConsumerState<_PropertiesContent> {
  String? _selectedId; // selected property id

  // Refreshes both the property list (incl. vacant) and the tenancy detail data.
  void _refresh() {
    ref.invalidate(landlordPropertiesProvider);
    ref.invalidate(landlordTenanciesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    // Properties (incl. vacant) drive the list; tenancies supply rich detail.
    final propsAsync = ref.watch(landlordPropertiesProvider);
    final tenancies = ref.watch(landlordTenanciesProvider).maybeWhen(
      data: (t) => t,
      orElse: () => const <Tenancy>[],
    );

    Tenancy? tenancyFor(String propertyId) {
      for (final t in tenancies) {
        if (t.propertyId == propertyId) return t;
      }
      return null;
    }

    final addButton = GestureDetector(
      onTap: () => showAddPropertySheet(context),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(10)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, color: Colors.white, size: 16), SizedBox(width: 4),
          Text('Add', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );

    return propsAsync.when(
      loading: () => const SkeletonTenancyList(),
      error: (_, __) => _emptyState(context, 'Could not load properties',
        icon: Icons.error_outline,
        onRetry: _refresh),
      data: (props) {
        if (props.isEmpty) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader(context, 'Your Properties', action: addButton),
            Expanded(child: _emptyState(context, "No properties yet.",
              icon: Icons.home_work_outlined,
              actionLabel: 'Add property',
              onAction: () => showAddPropertySheet(context))),
          ]);
        }

        // Card for a single property — reuses the rich tenancy card when let,
        // and a lightweight "vacant" card (→ add tenant) when empty.
        Widget cardFor(PropertyRecord pr, {bool selected = false, VoidCallback? onSelect}) {
          final t = tenancyFor(pr.id);
          if (t != null) {
            return TenancyCard(
              tenancy: t,
              canUploadDocs: true,
              isSelected: selected,
              onSelect: onSelect,
              onDelete: () => ref.read(deleteTenancyProvider.notifier).delete(pr.id),
            );
          }
          return _VacantPropertyCard(
            property: pr,
            isSelected: selected,
            onTap: onSelect ?? () => showAddTenantSheet(context, property: pr),
            onDelete: () => _confirmDeleteProperty(pr),
          );
        }

        // ── Desktop: split-pane ──────────────────────────────────────────────
        if (isDesktop) {
          final selId = (_selectedId != null && props.any((pr) => pr.id == _selectedId))
              ? _selectedId!
              : props.first.id;
          if (_selectedId == null || !props.any((pr) => pr.id == _selectedId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedId = selId);
            });
          }
          final selProp = props.firstWhere((pr) => pr.id == selId, orElse: () => props.first);
          final selTenancy = tenancyFor(selProp.id);

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Left card list ────────────────────────────────────────────
            SizedBox(
              width: 340,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionHeader(context, 'Properties', action: addButton),
                Expanded(child: RefreshIndicator(
                  color: _accent,
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: props.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final pr = props[i];
                      return cardFor(pr,
                        selected: pr.id == selId,
                        onSelect: () => setState(() => _selectedId = pr.id));
                    },
                  ),
                )),
              ]),
            ),

            // ── Divider ───────────────────────────────────────────────────
            Container(width: 1, color: p.border),

            // ── Right detail panel ────────────────────────────────────────
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(selProp.addressLine1,
                      style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [selProp.town, selProp.postcode].where((s) => s?.isNotEmpty == true).join(' · '),
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                  ])),
                ]),
              ),
              // Detail content
              Expanded(child: SingleChildScrollView(
                child: selTenancy != null
                    ? TenancyDetailPanel(
                        tenancy: selTenancy,
                        canUploadDocs: true,
                        onDelete: () => ref.read(deleteTenancyProvider.notifier).delete(selProp.id),
                      )
                    : _VacantDetailPanel(
                        property: selProp,
                        onAddTenant: () => showAddTenantSheet(context, property: selProp),
                        onDelete: () => _confirmDeleteProperty(selProp),
                      ),
              )),
            ])),
          ]);
        }

        // ── Mobile: list with bottom-sheet on tap ────────────────────────────
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(context, 'Your Properties', action: addButton),
          Expanded(child: RefreshIndicator(
            color: _accent,
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: props.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => cardFor(props[i]),
            ),
          )),
        ]);
      },
    );
  }

  void _confirmDeleteProperty(PropertyRecord pr) {
    final p = AbodePalette.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete property',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text, letterSpacing: -0.3)),
        content: Text(
          'Remove ${pr.addressLine1}? This permanently deletes the property and cannot be undone.',
          style: TextStyle(color: p.sub, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: p.muted))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(deleteTenancyProvider.notifier).delete(pr.id);
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

// ─── Vacant property card (no tenancy yet) ──────────────────────────────────────
class _VacantPropertyCard extends StatelessWidget {
  final PropertyRecord property;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _VacantPropertyCard({
    required this.property,
    required this.onTap,
    this.isSelected = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final pr = property;
    final location = [pr.town, pr.postcode].where((s) => s?.isNotEmpty == true).join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? p.amber.withValues(alpha: 0.4) : p.border,
          width: isSelected ? 1.5 : 0.8,
        ),
        boxShadow: p.cardShadow,
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: p.amber),
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(pr.addressLine1,
                    style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.amber.withValues(alpha: 0.2))),
                    child: Text('VACANT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: p.amber, letterSpacing: 0.5)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(location.isNotEmpty ? location : 'No location set',
                  style: TextStyle(fontSize: 12, color: p.muted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  if (pr.numBedrooms != null) ...[
                    _MiniSpec(Icons.bed_outlined, '${pr.numBedrooms} bed'),
                    const SizedBox(width: 6),
                  ],
                  if (pr.numBathrooms != null) ...[
                    _MiniSpec(Icons.bathtub_outlined, '${pr.numBathrooms} bath'),
                    const SizedBox(width: 6),
                  ],
                  if (pr.propertyType != null)
                    _MiniSpec(Icons.home_outlined, pr.propertyType![0].toUpperCase() + pr.propertyType!.substring(1)),
                  if (pr.epcRating != null) ...[
                    const SizedBox(width: 6),
                    _EpcBadge(pr.epcRating!),
                  ],
                  const Spacer(),
                  Icon(Icons.person_add_outlined, size: 16, color: p.amber),
                ]),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

class _MiniSpec extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniSpec(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: p.muted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: p.sub, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─── EPC rating badge ────────────────────────────────────────────────────────
class _EpcBadge extends StatelessWidget {
  final String rating;
  const _EpcBadge(this.rating);

  Color _color(BuildContext context) {
    final p = AbodePalette.of(context);
    switch (rating.toUpperCase()) {
      case 'A':
      case 'B': return p.green;
      case 'C':
      case 'D': return p.amber;
      default:  return p.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final p = AbodePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('EPC', style: TextStyle(color: p.muted, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
        const SizedBox(width: 4),
        Text(rating.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
      ]),
    );
  }
}

// ─── Vacant property detail panel (desktop) ─────────────────────────────────────
class _VacantDetailPanel extends StatelessWidget {
  final PropertyRecord property;
  final VoidCallback onAddTenant;
  final VoidCallback onDelete;
  const _VacantDetailPanel({
    required this.property,
    required this.onAddTenant,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final pr = property;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (pr.numBedrooms != null) _MiniSpec(Icons.bed_outlined, '${pr.numBedrooms} bed'),
          if (pr.numBathrooms != null) _MiniSpec(Icons.bathtub_outlined, '${pr.numBathrooms} bath'),
          if (pr.propertyType != null) _MiniSpec(Icons.home_outlined, pr.propertyType![0].toUpperCase() + pr.propertyType!.substring(1)),
          if (pr.epcRating != null) _EpcBadge(pr.epcRating!),
        ]),
        const SizedBox(height: 24),
        Center(child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: p.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.amber.withValues(alpha: 0.2))),
            child: Icon(Icons.home_outlined, color: p.amber, size: 30)),
          const SizedBox(height: 16),
          Text('No tenancy yet',
            style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text('Add a tenant or send a tenancy offer to start managing this property.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.sub, fontSize: 13, height: 1.5)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onAddTenant,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_add_outlined, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Add tenant', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onDelete,
            child: Text('Delete property',
              style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ])),
      ]),
    );
  }
}

// ─── Incidents tab ────────────────────────────────────────────────────────────
class _IncidentsContent extends ConsumerStatefulWidget {
  const _IncidentsContent();
  @override ConsumerState<_IncidentsContent> createState() => _IncidentsContentState();
}

class _IncidentsContentState extends ConsumerState<_IncidentsContent> {
  bool _archive = false;

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final incidentsAsync = ref.watch(landlordIncidentsProvider);

    Widget buildIncidentList(List<dynamic> list) {
      final incidents = list.cast<Incident>();
      if (isDesktop) {
        return LayoutBuilder(builder: (_, constraints) {
          final colW = (constraints.maxWidth - 52) / 2;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Wrap(
              spacing: 12, runSpacing: 12,
              children: incidents.map((incident) => SizedBox(
                width: colW,
                child: IncidentCard(
                  incident: incident,
                  role: 'landlord',
                  onAction: (action) async {
                    final n = ref.read(incidentActionsProvider.notifier);
                    if (action == 'approve_incident') {
                      await n.approveIncident(incident.id);
                    } else if (action == 'review_quote') {
                      if (context.mounted) showQuoteReviewSheet(context, incident: incident);
                    } else if (action == 'review_work') {
                      if (context.mounted) showJobReviewSheet(context, incident: incident);
                    } else if (action == 'view_dispute') {
                      if (context.mounted) showDisputeDetailSheet(context, incident: incident, role: 'landlord');
                    }
                  },
                  onViewThread: () => showIncidentCommentsSheet(context,
                    incidentId: incident.id, incidentTitle: incident.title, role: 'landlord'),
                ),
              )).toList(),
            ),
          );
        });
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        itemCount: incidents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => IncidentCard(
          incident: incidents[i],
          role: 'landlord',
          onAction: (action) async {
            final n = ref.read(incidentActionsProvider.notifier);
            if (action == 'approve_incident') {
              await n.approveIncident(incidents[i].id);
            } else if (action == 'review_quote') {
              if (context.mounted) showQuoteReviewSheet(context, incident: incidents[i]);
            } else if (action == 'review_work') {
              if (context.mounted) showJobReviewSheet(context, incident: incidents[i]);
            } else if (action == 'view_dispute') {
              if (context.mounted) showDisputeDetailSheet(context, incident: incidents[i], role: 'landlord');
            }
          },
          onViewThread: () => showIncidentCommentsSheet(context,
            incidentId: incidents[i].id, incidentTitle: incidents[i].title, role: 'landlord'),
        ),
      );
    }

    return RefreshIndicator(
      color: p.green,
      onRefresh: () async => ref.invalidate(landlordIncidentsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header: title + segmented control ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(children: [
            Text('Maintenance',
              style: TextStyle(
                color: p.text, fontSize: 22,
                fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const Spacer(),
            _SegmentedControl(
              left: 'Open',
              right: 'Done',
              showLeft: !_archive,
              onLeft:  () => setState(() => _archive = false),
              onRight: () => setState(() => _archive = true),
              p: p,
            ),
          ]),
        ),

        // ── Awaab's Law warning ────────────────────────────────────────
        if (!_archive)
          incidentsAsync.maybeWhen(
            data: (all) {
              final open    = all.where((i) => i.status != 'completed').toList();
              final overdue = open.where((i) => DateTime.now().difference(i.createdAt).inDays >= 14).length;
              final urgent  = open.where((i) {
                final d = DateTime.now().difference(i.createdAt).inDays;
                return d >= 7 && d < 14;
              }).length;
              if (overdue == 0 && urgent == 0) return const SizedBox.shrink();
              final isRed = overdue > 0;
              final col   = isRed ? p.red : p.amber;
              return _AlertBanner(
                icon: Icons.timer_outlined,
                color: col,
                message: [
                  if (overdue > 0) '$overdue overdue — Awaab\'s Law risk',
                  if (urgent > 0)  '$urgent approaching 14-day limit',
                ].join(' · '),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

        // ── List ───────────────────────────────────────────────────────
        Expanded(child: incidentsAsync.when(
          loading: () => const SkeletonIncidentList(),
          error: (_, __) => _emptyState(context, 'Could not load incidents',
            icon: Icons.error_outline,
            onRetry: () => ref.invalidate(landlordIncidentsProvider)),
          data: (all) {
            final list = all.where((i) => _archive
                ? i.status == 'completed'
                : i.status != 'completed').toList();
            if (list.isEmpty) return _IncidentEmptyState(archive: _archive);
            return buildIncidentList(list);
          },
        )),
      ]),
    );
  }
}

// ─── Segmented control ────────────────────────────────────────────────────────
class _SegmentedControl extends StatelessWidget {
  final String left, right;
  final bool showLeft;
  final VoidCallback onLeft, onRight;
  final AbodePalette p;
  const _SegmentedControl({
    required this.left, required this.right, required this.showLeft,
    required this.onLeft, required this.onRight, required this.p,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: p.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _Seg(label: left,  active: showLeft,  onTap: onLeft,  p: p),
      _Seg(label: right, active: !showLeft, onTap: onRight, p: p),
    ]),
  );
}

class _Seg extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AbodePalette p;
  const _Seg({required this.label, required this.active, required this.onTap, required this.p});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? p.card : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: active ? Border.all(color: p.border) : null,
      ),
      child: Text(label,
        style: TextStyle(
          color: active ? p.text : p.muted,
          fontSize: 13,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
    ),
  );
}

// ─── Empty state (incidents) ──────────────────────────────────────────────────
class _IncidentEmptyState extends StatelessWidget {
  final bool archive;
  const _IncidentEmptyState({required this.archive});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: archive
                  ? p.muted.withValues(alpha: 0.08)
                  : p.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: archive
                    ? p.muted.withValues(alpha: 0.15)
                    : p.green.withValues(alpha: 0.2))),
            child: Icon(
              archive ? Icons.history_rounded : Icons.check_circle_outline_rounded,
              color: archive ? p.muted : p.green,
              size: 34)),
          const SizedBox(height: 18),
          Text(
            archive ? 'No history yet' : 'All clear',
            style: TextStyle(
              color: p.text, fontSize: 20,
              fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text(
            archive
                ? 'Resolved maintenance issues will appear here once your tenants start reporting.'
                : 'No open maintenance issues right now.\nYour tenants can report issues directly through the app.',
            style: TextStyle(color: p.sub, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─── Compliance tab ───────────────────────────────────────────────────────────
class _ComplianceContent extends ConsumerWidget {
  const _ComplianceContent();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenanciesAsync = ref.watch(landlordTenanciesProvider);
    return RefreshIndicator(
      color: _accent, onRefresh: () async => ref.invalidate(landlordTenanciesProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(context, 'Compliance Documents'),
        Expanded(child: tenanciesAsync.when(
          loading: () => const SkeletonTenancyList(),
          error: (_, __) => _emptyState(context, 'Could not load compliance data',
            icon: Icons.error_outline,
            onRetry: () => ref.invalidate(landlordTenanciesProvider)),
          data: (list) {
            if (list.isEmpty) return _emptyState(context, 'Add a property first to track compliance.',
              icon: Icons.verified_user_outlined,
              actionLabel: 'Add property',
              onAction: () => showAddPropertySheet(context));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: list.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ComplianceCard(tenancy: list[i]),
            );
          },
        )),
      ]),
    );
  }
}

class _ComplianceCard extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  const _ComplianceCard({required this.tenancy});
  @override ConsumerState<_ComplianceCard> createState() => _ComplianceCardState();
}
class _ComplianceCardState extends ConsumerState<_ComplianceCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border), boxShadow: p.cardShadow),
      child: Column(children: [
        GestureDetector(onTap: () => setState(() => _expanded = !_expanded), behavior: HitTestBehavior.opaque,
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.home_outlined, color: _accent, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.tenancy.addressLine1, style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(widget.tenancy.postcode, style: TextStyle(color: p.sub, fontSize: 12)),
            ])),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: p.muted, size: 20),
          ]))),
        if (_expanded) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: ComplianceDocsPanel(tenancyId: widget.tenancy.tenancyId, canUpload: true)),
      ]),
    );
  }
}

// ─── Finances tab ─────────────────────────────────────────────────────────────
class _FinancesContent extends ConsumerWidget {
  const _FinancesContent();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final tenanciesAsync = ref.watch(landlordTenanciesProvider);
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    return RefreshIndicator(
      color: _accent, onRefresh: () async => ref.invalidate(landlordTenanciesProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        tenanciesAsync.when(
          loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            final active = list.where((t) => t.status == 'active').toList();
            final monthly = active.fold<double>(0, (s, t) => s + (t.monthlyRent ?? 0));
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(children: [
                _StatTile(context: context, value: fmt.format(monthly), label: 'Monthly Income', icon: Icons.trending_up, color: p.green),
                const SizedBox(width: 10),
                _StatTile(context: context, value: '${active.length}', label: 'Active', icon: Icons.home_outlined, color: _accent),
              ]),
            );
          },
        ),
        _sectionHeader(context, 'Rent by Property'),
        Expanded(child: tenanciesAsync.when(
          loading: () => const SkeletonTenancyList(),
          error: (_, __) => _emptyState(context, 'Could not load finances',
            icon: Icons.error_outline,
            onRetry: () => ref.invalidate(landlordTenanciesProvider)),
          data: (list) {
            if (list.isEmpty) return _emptyState(context, 'No properties added yet.',
              icon: Icons.payments_outlined,
              actionLabel: 'Add property',
              onAction: () => showAddPropertySheet(context));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: list.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final t = list[i];
                final hasReview = t.nextRentReviewDate != null &&
                    t.nextRentReviewDate!.difference(DateTime.now()).inDays <= 60;
                return Container(padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border), boxShadow: p.cardShadow),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.addressLine1, style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('${t.tenants.length} tenant${t.tenants.length == 1 ? "" : "s"} · ${t.status}', style: TextStyle(color: p.sub, fontSize: 12)),
                      ])),
                      Text(t.monthlyRent != null ? '${fmt.format(t.monthlyRent)}/mo' : '—',
                          style: TextStyle(color: p.green, fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                    if (hasReview) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: p.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.amber.withValues(alpha: 0.25))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.event_outlined, size: 12, color: p.amber),
                          const SizedBox(width: 5),
                          Text(
                            'Rent review: ${t.nextRentReviewDate!.day}/${t.nextRentReviewDate!.month}/${t.nextRentReviewDate!.year}'
                            ' (${t.nextRentReviewDate!.difference(DateTime.now()).inDays}d)',
                            style: TextStyle(color: p.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                        ])),
                    ],
                    if (t.referencingStatus != 'passed' && t.referencingStatus != 'not_started') ...[
                      const SizedBox(height: 6),
                      _ReferencingBadge(status: t.referencingStatus),
                    ],
                  ]),
                );
              },
            );
          },
        )),
      ]),
    );
  }
}

// ─── Hero card ────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final List<Tenancy> tenancies;
  final double monthlyIncome;
  final int activeCount;
  final int totalTenants;
  const _HeroCard({required this.tenancies, required this.monthlyIncome, required this.activeCount, required this.totalTenants});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    final annualIncome = monthlyIncome * 12;
    final bigNumColor = isDark ? Colors.white : p.text;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0E0F10), const Color(0xFF070708)]
              : [p.card, p.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.green.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(
          color: p.green.withValues(alpha: 0.08),
          blurRadius: 32, offset: const Offset(0, 10),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Top row — label + date
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: p.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.green.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: p.green, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: p.green.withValues(alpha: 0.6), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 5),
              Text('PORTFOLIO',
                style: TextStyle(color: p.green, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ]),
          ),
          const Spacer(),
          Text(DateFormat('MMM yyyy').format(DateTime.now()),
            style: TextStyle(color: p.sub, fontSize: 12)),
        ]),
        const SizedBox(height: 14),

        // Big number
        monthlyIncome > 0
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MONTHLY RENT',
                style: TextStyle(color: p.sub, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
              const SizedBox(height: 3),
              Text(fmt.format(monthlyIncome),
                style: TextStyle(
                  color: bigNumColor,
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -2.5,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
              const SizedBox(height: 4),
              Text('${fmt.format(annualIncome)} / year · $activeCount active',
                style: TextStyle(color: p.sub, fontSize: 13)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PROPERTIES',
                style: TextStyle(color: p.sub, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
              const SizedBox(height: 3),
              Text('${tenancies.length}',
                style: TextStyle(
                  color: bigNumColor, fontSize: 48,
                  fontWeight: FontWeight.w200, letterSpacing: -2.5, height: 1.0)),
              const SizedBox(height: 4),
              Text(tenancies.isEmpty
                  ? 'Add your first property to get started'
                  : '$totalTenants tenant${totalTenants == 1 ? "" : "s"} across ${tenancies.length} propert${tenancies.length == 1 ? "y" : "ies"}',
                style: TextStyle(color: p.sub, fontSize: 13)),
            ]),

        // Progress bar
        if (tenancies.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$activeCount of ${tenancies.length} properties active',
              style: TextStyle(color: p.sub, fontSize: 11)),
            Text('${(activeCount / tenancies.length * 100).round()}%',
              style: TextStyle(color: p.green, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: activeCount / tenancies.length,
              backgroundColor: bigNumColor.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(p.green),
              minHeight: 3,
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Bento stat tile ──────────────────────────────────────────────────────────
class _BentoStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final AbodePalette? p;
  const _BentoStat({required this.value, required this.label, required this.icon, required this.color, this.onTap, this.p});

  @override
  Widget build(BuildContext context) {
    final palette = p ?? AbodePalette.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 12),
            Text(value,
              style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
            const SizedBox(height: 3),
            Text(label,
              style: TextStyle(color: palette.muted, fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

// ─── Quick actions ────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final VoidCallback onGoToIncidents;
  final VoidCallback onGoToProperties;
  final VoidCallback onGoToCompliance;
  final VoidCallback onGoToMessages;
  const _QuickActions({
    required this.onGoToIncidents,
    required this.onGoToProperties,
    required this.onGoToCompliance,
    required this.onGoToMessages,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final actions = [
      (Icons.add_home_work_outlined, 'Add Property', () => showAddPropertySheet(context)),
      (Icons.build_outlined,         'Log Issue',    onGoToIncidents),
      (Icons.verified_user_outlined, 'Compliance',   onGoToCompliance),
      (Icons.chat_bubble_outline_rounded, 'Messages', onGoToMessages),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Text('Quick Actions',
          style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      SizedBox(
        height: 48,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: actions.length,
          itemBuilder: (_, i) {
            final (icon, label, onTap) = actions[i];
            return GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 16, color: p.sub),
                  const SizedBox(width: 8),
                  Text(label,
                    style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─── Compliance alert banner ──────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final VoidCallback? onTap;
  const _AlertBanner({required this.icon, required this.color, required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(message,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500))),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 12),
        ]),
      ),
    );
  }
}

// ─── Activity feed ────────────────────────────────────────────────────────────
class _ActivityFeed extends ConsumerWidget {
  final AsyncValue<List<Incident>> incidentsAsync;
  final VoidCallback onGoToIncidents;
  final WidgetRef ref;
  const _ActivityFeed({required this.incidentsAsync, required this.onGoToIncidents, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final p = AbodePalette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 0, 14),
        child: Row(children: [
          Text('Maintenance',
            style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const Spacer(),
          GestureDetector(
            onTap: onGoToIncidents,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text('See all',
                style: TextStyle(color: p.green, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
      incidentsAsync.when(
        loading: () => const SkeletonIncidentList(count: 2),
        error: (_, __) => const SizedBox.shrink(),
        data: (list) {
          final open = list.where((i) => i.status != 'completed').take(4).toList();
          if (open.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: p.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.check_circle_outline, color: p.green, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('All clear — no open issues',
                    style: TextStyle(color: p.sub, fontSize: 14)),
                ]),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: open.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final incident = entry.value;
                  final isLast = idx == open.length - 1;
                  final age = DateTime.now().difference(incident.createdAt).inDays;
                  final isUrgent = age >= 14;
                  final dotColor = isUrgent ? p.red : age >= 7 ? p.amber : _accent;

                  return GestureDetector(
                    onTap: () => showIncidentCommentsSheet(context,
                      incidentId: incident.id, incidentTitle: incident.title, role: 'landlord'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: isLast ? null : Border(
                          bottom: BorderSide(color: p.border, width: 0.5)),
                      ),
                      child: Row(children: [
                        // Timeline dot + spine
                        SizedBox(width: 16, child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: dotColor, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.45), blurRadius: 5)],
                              ),
                            ),
                          ],
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(incident.title,
                              style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(incident.propertyAddress ?? incident.status,
                              style: TextStyle(color: p.sub, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        )),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(age == 0 ? 'Today' : age == 1 ? '1d ago' : '${age}d ago',
                            style: TextStyle(color: p.muted, fontSize: 11)),
                          if (isUrgent) ...[
                            const SizedBox(height: 2),
                            Text('Urgent',
                              style: TextStyle(color: p.red, fontSize: 10, fontWeight: FontWeight.w700)),
                          ],
                        ]),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: p.muted, size: 16),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    ]);
  }
}

// ─── Key dates section ────────────────────────────────────────────────────────
class _KeyDate {
  final String label, sub;
  final DateTime date;
  final Color color;
  final IconData icon;
  const _KeyDate({required this.label, required this.sub, required this.date, required this.color, required this.icon});
}

class _KeyDatesSection extends StatelessWidget {
  final List<Tenancy> tenancies;
  final VoidCallback onGoToProperties;
  const _KeyDatesSection({required this.tenancies, required this.onGoToProperties});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final now = DateTime.now();
    final events = <_KeyDate>[];

    for (final t in tenancies) {
      // Under RRA all tenancies are periodic — show notice periods, not end dates.
      // Only show end date if notice has NOT been served (legacy fixed-term data).
      if (t.endDate != null && t.noticeServedDate == null) {
        final days = t.endDate!.difference(now).inDays;
        if (days >= 0 && days <= 90) {
          events.add(_KeyDate(
            label: 'Review renewal', sub: t.addressLine1,
            date: t.endDate!,
            color: days <= 14 ? p.red : days <= 30 ? p.amber : p.green,
            icon: Icons.home_outlined,
          ));
        }
      }
      if (t.expectedVacateDate != null) {
        final days = t.expectedVacateDate!.difference(now).inDays;
        if (days >= 0 && days <= 60) {
          events.add(_KeyDate(
            label: 'S8 notice — vacate', sub: t.addressLine1,
            date: t.expectedVacateDate!,
            color: days <= 14 ? p.red : p.amber,
            icon: Icons.exit_to_app_outlined,
          ));
        }
      }
      if (t.nextRentReviewDate != null) {
        final days = t.nextRentReviewDate!.difference(now).inDays;
        if (days >= 0 && days <= 90) {
          events.add(_KeyDate(
            label: 'Rent review due', sub: t.addressLine1,
            date: t.nextRentReviewDate!,
            color: days <= 14 ? p.amber : p.green,
            icon: Icons.trending_up_rounded,
          ));
        }
      }
    }

    if (events.isEmpty) return const SizedBox.shrink();
    events.sort((a, b) => a.date.compareTo(b.date));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Upcoming', style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: p.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('${events.length}', style: TextStyle(color: p.amber, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        // Horizontal scroll cards
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: events.take(5).length,
            itemBuilder: (_, i) {
              final e = events[i];
              final daysLeft = e.date.difference(DateTime.now()).inDays;
              return Container(
                width: 180,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: e.color.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(e.icon, size: 13, color: e.color),
                    const SizedBox(width: 5),
                    Expanded(child: Text(e.label,
                      style: TextStyle(color: e.color, fontSize: 11, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  Text(e.sub,
                    style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Text(daysLeft == 0 ? 'Today' : daysLeft == 1 ? 'Tomorrow' : 'In $daysLeft days',
                    style: TextStyle(color: p.muted, fontSize: 11)),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}


// ─── Right to Rent strip ──────────────────────────────────────────────────────
class _RtrCheckStrip extends StatelessWidget {
  final Tenancy tenancy;
  const _RtrCheckStrip({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: () => _showRtrChecklist(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.amber.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.amber.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.badge_outlined, size: 15, color: p.amber),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Right to Rent check not completed', style: TextStyle(color: p.amber, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('Tap for checklist — required by UK law', style: TextStyle(color: p.sub, fontSize: 11)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 14, color: p.amber),
        ]),
      ),
    );
  }

  void _showRtrChecklist(BuildContext context) {
    showAdaptiveSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88, maxChildSize: 0.94, minChildSize: 0.5,
        builder: (_, sc) => _RtrChecklistSheet(tenancy: tenancy, scrollController: sc),
      ),
    );
  }
}

class _RtrChecklistSheet extends StatefulWidget {
  final Tenancy tenancy;
  final ScrollController scrollController;
  const _RtrChecklistSheet({required this.tenancy, required this.scrollController});
  @override State<_RtrChecklistSheet> createState() => _RtrChecklistSheetState();
}

class _RtrChecklistSheetState extends State<_RtrChecklistSheet> {
  late Map<int, bool> _checked;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final mask = widget.tenancy.rtrChecklistMask;
    _checked = {
      for (var i = 0; i < _items.length; i++) i: (mask >> i) & 1 == 1,
    };
  }

  static const _items = [
    'Obtained original documents (passport, BRP, e-visa share code, or EUSS status)',
    'Documents are genuine, current and belong to the occupant — checked in person',
    'Used the Home Office online checking service (if required for biometric holders)',
    'Made clear copies of all documents and stored them securely',
    'Recorded the date the check was carried out',
    'Set a follow-up date if the tenant has time-limited right to rent',
    'Provided tenant with a written record / confirmation of their right to rent status',
  ];

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final doneCount = _checked.values.where((v) => v).length;
    final total = _items.length;
    final allDone = doneCount == total;

    return Container(
      decoration: BoxDecoration(color: p.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Row(children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(color: p.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.badge_outlined, color: p.amber, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Right to Rent Checklist', style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700)),
              Text(
                widget.tenancy.tenants.isNotEmpty
                    ? (widget.tenancy.tenants.first.fullName ?? widget.tenancy.addressOneLiner)
                    : widget.tenancy.addressOneLiner,
                style: TextStyle(color: p.sub, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.amber.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: p.amber.withValues(alpha: 0.2))),
            child: Text(
              'Under the Immigration Act 2014, you must check that all adult '
              'occupants have the right to rent in England before the tenancy '
              'begins. Failure to comply can result in an unlimited fine.',
              style: TextStyle(color: p.sub, fontSize: 12, height: 1.5)),
          ),
          const SizedBox(height: 20),
          Text('Checklist', style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ..._items.asMap().entries.map((e) {
            final checked = _checked[e.key] ?? false;
            return GestureDetector(
              onTap: _saving ? null : () => _toggle(e.key, checked),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: checked ? p.green.withValues(alpha: 0.06) : p.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: checked ? p.green.withValues(alpha: 0.3) : p.border)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 20, height: 20, margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: checked ? p.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: checked ? p.green : p.muted)),
                    child: checked ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value,
                    style: TextStyle(color: checked ? p.sub : p.text, fontSize: 12, height: 1.4,
                      decoration: checked ? TextDecoration.lineThrough : null))),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Progress', style: TextStyle(color: p.sub, fontSize: 12)),
            Text('$doneCount / $total', style: TextStyle(color: allDone ? p.green : p.amber, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : doneCount / total,
              backgroundColor: p.border,
              valueColor: AlwaysStoppedAnimation(allDone ? p.green : p.amber),
              minHeight: 6),
          ),
          if (allDone) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.green.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: p.green.withValues(alpha: 0.25))),
              child: Row(children: [
                Icon(Icons.check_circle_outline, color: p.green, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Right to Rent check complete — store document copies securely for the duration of the tenancy plus one year.',
                  style: TextStyle(color: p.green, fontSize: 12, height: 1.4))),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: p.muted, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'For time-limited right to rent, repeat the check before the expiry date. '
                'You can check using the Home Office online checking service: '
                'gov.uk/landlords-online-right-to-rent-checks',
                style: TextStyle(color: p.muted, fontSize: 11, height: 1.4))),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(int index, bool current) async {
    setState(() {
      _checked[index] = !current;
      _saving = true;
    });
    try {
      await supabase.from('tenancies').update({
        'rtr_checklist_mask': _maskFromChecked(),
      }).eq('id', widget.tenancy.id);
    } catch (_) {
      // revert on failure
      setState(() => _checked[index] = current);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _maskFromChecked() {
    var mask = 0;
    for (var i = 0; i < _items.length; i++) {
      if (_checked[i] == true) mask |= (1 << i);
    }
    return mask;
  }
}

// ─── Referencing badge ────────────────────────────────────────────────────────
class _ReferencingBadge extends StatelessWidget {
  final String status;
  const _ReferencingBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final color = switch (status) {
      'in_progress'  => _accent,
      'failed'       => p.red,
      'conditional'  => p.amber,
      _              => p.sub,
    };
    final label = switch (status) {
      'in_progress'  => 'Referencing in progress',
      'failed'       => 'Referencing failed',
      'conditional'  => 'Conditional pass',
      _              => 'Referencing: $status',
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.person_search_outlined, size: 12, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ─── Portfolio health (kept for reference, no longer shown in overview) ───────
class _PortfolioHealthCard extends StatelessWidget {
  final List<Tenancy> tenancies;
  final List<Incident> incidents;
  final VoidCallback onGoToCompliance;
  const _PortfolioHealthCard({required this.tenancies, required this.incidents, required this.onGoToCompliance});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final openIncidents = incidents.where((i) => i.status != 'completed').toList();
    final slaBreaches = openIncidents.where((i) => DateTime.now().difference(i.createdAt).inDays > 14).length;
    final refPassed = tenancies.where((t) => t.referencingStatus == 'passed').length;
    final refTotal  = tenancies.isEmpty ? 1 : tenancies.length;

    final health = slaBreaches > 0 ? 'Needs Attention' : openIncidents.isEmpty ? 'Excellent' : 'Good';
    final healthColor = slaBreaches > 0 ? p.red : openIncidents.isEmpty ? p.green : p.amber;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border), boxShadow: p.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: healthColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.health_and_safety_outlined, color: healthColor, size: 18)),
          const SizedBox(width: 10),
          Text('Portfolio Health', style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: healthColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(health, style: TextStyle(color: healthColor, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _HealthMetric(p, 'Active', '${tenancies.where((t) => t.status == "active").length}', Icons.home_outlined, _accent),
          const SizedBox(width: 10),
          _HealthMetric(p, 'Referencing', '${(refPassed / refTotal * 100).round()}%', Icons.verified_user_outlined, p.green),
          const SizedBox(width: 10),
          _HealthMetric(p, 'Open Issues', '${openIncidents.length}', Icons.build_outlined, openIncidents.isEmpty ? p.green : p.amber),
          const SizedBox(width: 10),
          () {
            final rtrPending = tenancies.where((t) =>
              t.referencingStatus == 'not_started' &&
              t.status != 'expired' && t.status != 'terminated').length;
            return _HealthMetric(p, 'RTR', rtrPending == 0 ? '✓' : '$rtrPending',
              Icons.badge_outlined, rtrPending == 0 ? p.green : p.amber);
          }(),
        ]),
        if (slaBreaches > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: p.red.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: p.red.withValues(alpha: 0.2))),
            child: Row(children: [
              Icon(Icons.timer_outlined, color: p.red, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '$slaBreaches incident${slaBreaches == 1 ? "" : "s"} may breach the 14-day Awaab\'s Law response requirement',
                style: TextStyle(color: p.red, fontSize: 12))),
            ])),
        ],
      ]),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  final AbodePalette p;
  final String title, value;
  final IconData icon;
  final Color color;
  const _HealthMetric(this.p, this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      Text(title, style: TextStyle(color: p.muted, fontSize: 10)),
    ]));
}

// ─── Action Center Sidebar (permanent, always visible on desktop) ──────────────
class _ActionCenterSidebar extends ConsumerWidget {
  final void Function(_LTab) onGoToTab;
  const _ActionCenterSidebar({required this.onGoToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final now = DateTime.now();
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    final certsAsync     = ref.watch(landlordComplianceCertsProvider);
    final incidentsAsync = ref.watch(landlordIncidentsProvider);
    final paymentsAsync  = ref.watch(landlordAllRentPaymentsProvider);
    final unread         = ref.watch(unreadNotificationCountProvider);

    // Overdue rent payments (past due date, not paid)
    final overduePayments = (paymentsAsync.valueOrNull ?? [])
        .where((r) => r.isOverdue)
        .toList();

    // Certs expiring within 30 days (or already expired)
    final expiringCerts = (certsAsync.valueOrNull ?? [])
        .where((c) => c.daysUntilExpiry <= 30)
        .toList()
      ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    // Open maintenance issues older than 7 days
    final staleIncidents = (incidentsAsync.valueOrNull ?? [])
        .where((i) => i.status != 'completed' &&
            now.difference(i.createdAt).inDays >= 7)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final allClear = overduePayments.isEmpty &&
        expiringCerts.isEmpty &&
        staleIncidents.isEmpty &&
        unread == 0;

    final isLoading = paymentsAsync.isLoading ||
        certsAsync.isLoading ||
        incidentsAsync.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Action Center',
                style: TextStyle(color: p.text, fontSize: 14,
                    fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              const SizedBox(height: 1),
              Text(DateFormat('EEE d MMM').format(now),
                style: TextStyle(color: p.muted, fontSize: 11)),
            ])),
            if (!allClear && !isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.red.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '${overduePayments.length + expiringCerts.length + staleIncidents.length + (unread > 0 ? 1 : 0)}',
                  style: TextStyle(color: p.red, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: isLoading
              ? const _ActionCenterSkeleton()
              : allClear
                  ? _ActionCenterAllClear(p: p)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (overduePayments.isNotEmpty) ...[
                            _AcSectionHeader(label: 'Overdue Rent', color: p.red, p: p),
                            ...overduePayments.take(5).map((payment) =>
                              _AcRentTile(payment: payment, fmt: fmt, p: p,
                                onTap: () => onGoToTab(_LTab.properties))),
                          ],
                          if (expiringCerts.isNotEmpty) ...[
                            _AcSectionHeader(label: 'Expiring Certs', color: p.amber, p: p),
                            ...expiringCerts.take(5).map((cert) =>
                              _AcCertTile(cert: cert, p: p,
                                onTap: () => onGoToTab(_LTab.compliance))),
                          ],
                          if (staleIncidents.isNotEmpty) ...[
                            _AcSectionHeader(label: 'Maintenance', color: p.amber, p: p),
                            ...staleIncidents.take(5).map((incident) =>
                              _AcIncidentTile(incident: incident, p: p,
                                onTap: () => onGoToTab(_LTab.incidents))),
                          ],
                          if (unread > 0) ...[
                            _AcSectionHeader(label: 'Messages', color: _accent, p: p),
                            _AcMessagesTile(count: unread, p: p,
                              onTap: () => onGoToTab(_LTab.messages)),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────
class _AcSectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final AbodePalette p;
  const _AcSectionHeader({required this.label, required this.color, required this.p});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Row(children: [
      Container(width: 3, height: 11,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 7),
      Text(label,
        style: TextStyle(color: p.sub, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    ]),
  );
}

// ── Overdue rent tile ──────────────────────────────────────────────────────────
class _AcRentTile extends StatelessWidget {
  final RentPayment payment;
  final NumberFormat fmt;
  final AbodePalette p;
  final VoidCallback onTap;
  const _AcRentTile({required this.payment, required this.fmt, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final daysOverdue = DateTime.now().difference(payment.dueDate).inDays;
    final isMissed = daysOverdue > 7;
    final col = isMissed ? p.red : p.amber;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.payments_outlined, size: 15, color: col),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fmt.format(payment.amountDue - payment.amountPaid),
              style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w700)),
            Text('${payment.monthLabel} · ${daysOverdue}d overdue',
              style: TextStyle(color: p.muted, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Icon(Icons.chevron_right_rounded, size: 14, color: p.muted),
        ]),
      ),
    );
  }
}

// ── Expiring cert tile ─────────────────────────────────────────────────────────
class _AcCertTile extends StatelessWidget {
  final ComplianceCertificate cert;
  final AbodePalette p;
  final VoidCallback onTap;
  const _AcCertTile({required this.cert, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = cert.daysUntilExpiry;
    final isExpired = days < 0;
    final col = isExpired ? p.red : days <= 7 ? p.red : p.amber;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.verified_user_outlined, size: 15, color: col),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cert.displayType,
              style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(isExpired
                ? 'Expired ${(-days)}d ago'
                : days == 0 ? 'Expires today' : 'Expires in ${days}d',
              style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w600)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 14, color: p.muted),
        ]),
      ),
    );
  }
}

// ── Stale maintenance tile ─────────────────────────────────────────────────────
class _AcIncidentTile extends StatelessWidget {
  final Incident incident;
  final AbodePalette p;
  final VoidCallback onTap;
  const _AcIncidentTile({required this.incident, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(incident.createdAt).inDays;
    final col = age >= 14 ? p.red : p.amber;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.build_outlined, size: 15, color: col),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(incident.title,
              style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${age}d open${age >= 14 ? " · Awaab's Law" : ""}',
              style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Icon(Icons.chevron_right_rounded, size: 14, color: p.muted),
        ]),
      ),
    );
  }
}

// ── Unread messages tile ───────────────────────────────────────────────────────
class _AcMessagesTile extends StatelessWidget {
  final int count;
  final AbodePalette p;
  final VoidCallback onTap;
  const _AcMessagesTile({required this.count, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: _accent),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count unread ${count == 1 ? "message" : "messages"}',
            style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
          Text('Tap to open messages',
            style: TextStyle(color: p.muted, fontSize: 10)),
        ])),
        Icon(Icons.chevron_right_rounded, size: 14, color: p.muted),
      ]),
    ),
  );
}

// ── All clear state ────────────────────────────────────────────────────────────
class _ActionCenterAllClear extends StatelessWidget {
  final AbodePalette p;
  const _ActionCenterAllClear({required this.p});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: p.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.green.withValues(alpha: 0.2)),
          ),
          child: Icon(Icons.check_circle_outline_rounded, color: p.green, size: 26),
        ),
        const SizedBox(height: 14),
        Text('All clear', style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('No rent arrears, expiring certificates, or stale issues.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 12, height: 1.4)),
      ]),
    ),
  );
}

// ── Skeleton loader ────────────────────────────────────────────────────────────
class _ActionCenterSkeleton extends StatelessWidget {
  const _ActionCenterSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: 50, margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: p.card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.border)),
          ),
        ],
      ]),
    );
  }
}
