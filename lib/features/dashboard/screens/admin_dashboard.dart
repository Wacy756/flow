import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../providers/dashboard_providers.dart';
import 'admin_disputes_screen.dart';
import 'admin_payouts_screen.dart';
import 'admin_theme.dart';
import 'admin_users_screen.dart';
import 'contractor_admin_screen.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final statsAsync   = ref.watch(adminStatsProvider);
    final email        = supabase.auth.currentUser?.email ?? '';

    return Theme(
      data: AP.appBarTheme(context),
      child: Scaffold(
        backgroundColor: AP.bg,
        body: SafeArea(
          child: AdminConstraint(child: RefreshIndicator(
            color: AP.accent,
            backgroundColor: AP.card,
            onRefresh: () async {
              ref.invalidate(adminStatsProvider);
              ref.invalidate(adminOpenDisputesProvider);
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [

                // ── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B2B), Color(0xFFFF8C42)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('Abode Admin',
                              style: TextStyle(
                                color: AP.text, fontSize: 17,
                                fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AP.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AP.accent.withValues(alpha: 0.3)),
                              ),
                              child: const Text('ADMIN',
                                style: TextStyle(
                                  color: AP.accent, fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8)),
                            ),
                          ]),
                          profileAsync.maybeWhen(
                            data: (p) => Text(p?.fullName ?? email,
                              style: const TextStyle(
                                color: AP.sub, fontSize: 12)),
                            orElse: () => Text(email,
                              style: const TextStyle(
                                color: AP.sub, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await supabase.auth.signOut();
                        if (context.mounted) context.go(AppRoutes.landing);
                      },
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AP.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AP.el),
                        ),
                        child: const Icon(Icons.logout_rounded,
                          color: AP.sub, size: 17),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Hero revenue card ───────────────────────────────────────
                statsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(
                      color: AP.accent, strokeWidth: 2))),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (stats) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [

                      // Revenue hero card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: AP.heroGradient,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AP.accent.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AP.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AP.accent.withValues(alpha: 0.25)),
                                ),
                                child: const Text('PLATFORM REVENUE',
                                  style: TextStyle(
                                    color: AP.accent, fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8)),
                              ),
                            ]),
                            const SizedBox(height: 14),
                            Text(
                              '£${stats.totalPlatformFees.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AP.text, fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5),
                            ),
                            const SizedBox(height: 2),
                            const Text('Fees earned from completed jobs',
                              style: TextStyle(color: AP.sub, fontSize: 12)),
                            const SizedBox(height: 20),
                            Container(
                              height: 1, color: AP.el),
                            const SizedBox(height: 16),
                            Row(children: [
                              _MiniStat(
                                value: '${stats.landlords}',
                                label: 'Landlords'),
                              _VertDivider(),
                              _MiniStat(
                                value: '${stats.tenants}',
                                label: 'Tenants'),
                              _VertDivider(),
                              _MiniStat(
                                value: '${stats.contractors}',
                                label: 'Contractors'),
                              _VertDivider(),
                              _MiniStat(
                                value: '${stats.totalProperties}',
                                label: 'Properties'),
                            ]),
                            const SizedBox(height: 12),
                            Container(height: 1, color: AP.el),
                            const SizedBox(height: 12),
                            Row(children: [
                              _MiniStat(
                                value: '${stats.totalUsers}',
                                label: 'Total users'),
                              _VertDivider(),
                              _MiniStat(
                                value: '${stats.agents}',
                                label: 'Agents'),
                              _VertDivider(),
                              _MiniStat(
                                value: '${stats.activeTenancies}',
                                label: 'Tenancies'),
                              _VertDivider(),
                              _MiniStat(
                                value: stats.pendingVetting > 0
                                    ? '${stats.pendingVetting}'
                                    : '—',
                                label: 'Pending'),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Status pills
                      Row(children: [
                        _StatusPill(
                          icon: stats.openDisputes > 0
                              ? Icons.gavel_rounded
                              : Icons.check_circle_outline_rounded,
                          label: stats.openDisputes > 0
                              ? '${stats.openDisputes} open dispute${stats.openDisputes == 1 ? '' : 's'}'
                              : 'No open disputes',
                          color: stats.openDisputes > 0 ? AP.red : AP.green),
                        const SizedBox(width: 8),
                        _StatusPill(
                          icon: stats.pendingVetting > 0
                              ? Icons.hourglass_empty_rounded
                              : Icons.verified_user_outlined,
                          label: stats.pendingVetting > 0
                              ? '${stats.pendingVetting} pending vetting'
                              : 'All contractors vetted',
                          color: stats.pendingVetting > 0
                              ? AP.amber : AP.green),
                      ]),

                    ]),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Tools label ────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('TOOLS',
                    style: TextStyle(
                      color: AP.muted, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 0.9)),
                ),
                const SizedBox(height: 10),

                // ── Grouped menu ───────────────────────────────────────────
                statsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                  data: (stats) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AP.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AP.cardBorder),
                      ),
                      child: Column(children: [
                        _MenuItem(
                          icon: Icons.verified_user_outlined,
                          label: 'Contractor Management',
                          sub: 'Review, approve and invite contractors',
                          badge: stats.pendingVetting > 0
                              ? '${stats.pendingVetting}' : null,
                          badgeColor: AP.amber,
                          isFirst: true,
                          onTap: () => _push(context,
                            const ContractorAdminScreen()),
                        ),
                        _MenuDivider(),
                        _MenuItem(
                          icon: Icons.gavel_rounded,
                          label: 'Disputes',
                          sub: 'Resolve stuck payment disputes',
                          badge: stats.openDisputes > 0
                              ? '${stats.openDisputes}' : null,
                          badgeColor: AP.red,
                          onTap: () => _push(context,
                            const AdminDisputesScreen()),
                        ),
                        _MenuDivider(),
                        _MenuItem(
                          icon: Icons.people_outline_rounded,
                          label: 'Users',
                          sub: 'Browse all platform users',
                          onTap: () => _push(context,
                            const AdminUsersScreen()),
                        ),
                        _MenuDivider(),
                        _MenuItem(
                          icon: Icons.receipt_long_outlined,
                          label: 'Payout Audit',
                          sub: 'Full log of released contractor payments',
                          isLast: true,
                          onTap: () => _push(context,
                            const AdminPayoutsScreen()),
                        ),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          )),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen));
  }
}

// ─── Mini stat (inside hero card) ─────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value,
        style: const TextStyle(
          color: AP.text, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label,
        style: const TextStyle(color: AP.sub, fontSize: 10)),
    ]),
  );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 32, color: AP.el, margin: const EdgeInsets.symmetric(horizontal: 2));
}

// ─── Status pill ──────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 7),
        Flexible(
          child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    ),
  );
}

// ─── Menu item ────────────────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final String? badge;
  final Color? badgeColor;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top:    isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast  ? const Radius.circular(16) : Radius.zero,
        ),
        splashColor: AP.accent.withValues(alpha: 0.05),
        highlightColor: AP.el.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AP.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AP.accent, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: const TextStyle(
                      color: AP.text, fontSize: 15,
                      fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(sub,
                    style: const TextStyle(color: AP.sub, fontSize: 12)),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AP.accent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (badgeColor ?? AP.accent).withValues(alpha: 0.25)),
                ),
                child: Text(badge!,
                  style: TextStyle(
                    color: badgeColor ?? AP.accent,
                    fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded,
              color: AP.muted, size: 18),
          ]),
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 1, color: AP.el,
    margin: const EdgeInsets.only(left: 68));
}
