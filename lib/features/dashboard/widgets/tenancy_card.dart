import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../providers/dashboard_providers.dart';
import '../models/tenancy.dart';
import '../screens/check_in_report_screen.dart';
import 'end_tenancy_sheet.dart';
import 'holding_deposit_sheet.dart';
import 'invite_tenant_sheet.dart';
import 'rent_ledger_sheet.dart';
import 'right_to_rent_sheet.dart';
import 'tenancy_details_sheet.dart';
import 'serve_notice_sheet.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Public widget ────────────────────────────────────────────────────────────
class TenancyCard extends StatelessWidget {
  final Tenancy tenancy;
  final bool canUploadDocs;
  final VoidCallback? onViewCompliance;
  final VoidCallback? onDelete;
  // If provided, tap calls this instead of opening a bottom sheet (used on desktop split-pane)
  final VoidCallback? onSelect;
  final bool isSelected;

  const TenancyCard({
    super.key,
    required this.tenancy,
    this.canUploadDocs = false,
    this.onViewCompliance,
    this.onDelete,
    this.onSelect,
    this.isSelected = false,
  });

  static Color _statusColor(String status, AbodePalette p) => switch (status) {
    'active'     => p.green,
    'pending'    => p.amber,
    'expired'    => p.red,
    'terminated' => p.red,
    _            => p.sub,
  };

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final t = tenancy;
    final statusColor = _statusColor(t.status, p);
    final hasTenants = t.tenants.isNotEmpty;
    final location = [t.town, t.postcode].where((s) => s?.isNotEmpty == true).join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? statusColor.withValues(alpha: 0.4) : p.border,
          width: isSelected ? 1.5 : 0.8,
        ),
        boxShadow: p.cardShadow,
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (onSelect != null) {
            onSelect!();
          } else {
            showTenancyDetailsSheet(context, tenancy: t);
          }
        },
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Main content
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(
                    t.addressLine1,
                    style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 12),
                  if (t.monthlyRent != null)
                    Text('£${t.monthlyRent!.toStringAsFixed(0)}/mo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.green, letterSpacing: -0.3)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Expanded(child: Text(
                    location.isNotEmpty ? location : (hasTenants ? t.tenants.map((x) => x.fullName ?? '—').join(', ') : 'No tenants'),
                    style: TextStyle(fontSize: 12, color: p.muted),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  _StatusPill(status: t.status),
                ]),
                if (hasTenants || t.numBedrooms != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    if (t.numBedrooms != null) ...[
                      _SpecChip(Icons.bed_outlined, '${t.numBedrooms} bed'),
                      const SizedBox(width: 6),
                    ],
                    if (t.numBathrooms != null) ...[
                      _SpecChip(Icons.bathtub_outlined, '${t.numBathrooms} bath'),
                      const SizedBox(width: 6),
                    ],
                    if (hasTenants)
                      _SpecChip(Icons.person_outline, t.tenants.first.fullName ?? '—'),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: p.muted, size: 18),
                  ]),
                ] else
                  Align(alignment: Alignment.centerRight,
                    child: Icon(Icons.chevron_right_rounded, color: p.muted, size: 18)),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

// ─── Detail panel (public — used in desktop split-pane) ───────────────────────
class TenancyDetailPanel extends ConsumerWidget {
  final Tenancy tenancy;
  final bool canUploadDocs;
  final VoidCallback? onViewCompliance;
  final VoidCallback? onDelete;

  const TenancyDetailPanel({
    super.key,
    required this.tenancy,
    required this.canUploadDocs,
    this.onViewCompliance,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final t = tenancy;
    final needsRtr = t.rtrStatus != 'completed' &&
        t.status != 'expired' && t.status != 'terminated';
    final rtrRecheckDue = !needsRtr &&
        t.rtrCheckDate != null &&
        DateTime.now().difference(t.rtrCheckDate!).inDays > 365 &&
        t.status != 'expired' && t.status != 'terminated';

    final hasProtection = t.depositScheme != null && t.depositScheme!.isNotEmpty &&
        t.depositRef != null && t.depositRef!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Sub-address only (header already shows town + postcode) ───────
        if (t.addressLine2?.isNotEmpty == true || t.addressLine3?.isNotEmpty == true) ...[
          Text(
            [
              if (t.addressLine2?.isNotEmpty == true) t.addressLine2!,
              if (t.addressLine3?.isNotEmpty == true) t.addressLine3!,
            ].join(', '),
            style: TextStyle(color: p.muted, fontSize: 12)),
          const SizedBox(height: 6),
        ],
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (t.numBedrooms  != null) _SpecChip(Icons.bed_outlined,      '${t.numBedrooms} bed'),
          if (t.numBathrooms != null) _SpecChip(Icons.bathtub_outlined,  '${t.numBathrooms} bath'),
          if (t.propertyType != null) _SpecChip(Icons.home_outlined,     _cap(t.propertyType!)),
          if (t.furnishing   != null) _SpecChip(Icons.chair_outlined,    _cap(t.furnishing!)),
          if (t.maxTenants   != null) _SpecChip(Icons.people_outline,    'Max ${t.maxTenants}'),
        ]),

        const SizedBox(height: 16),
        Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
        const SizedBox(height: 14),

        // ── Application review — first priority when pending ───────────────
        if (canUploadDocs && t.status == 'pending') ...[
          _ApplicationReviewSection(tenancy: t, ref: ref, p: p),
          const SizedBox(height: 14),
          Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
        ],

        // ── Financials ────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Monthly — dominant (no label, the number speaks)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              t.monthlyRent != null ? '£${t.monthlyRent!.toStringAsFixed(0)}' : '—',
              style: TextStyle(color: p.green, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1.2)),
            const SizedBox(height: 1),
            Text('per month', style: TextStyle(color: p.muted, fontSize: 11)),
          ]),
          const SizedBox(width: 24),
          // Secondary figures
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _FinanceLine(label: 'Annual',  value: t.monthlyRent != null ? '£${(t.monthlyRent! * 12).toStringAsFixed(0)}' : '—', p: p),
            const SizedBox(height: 6),
            _FinanceLine(label: 'Deposit', value: t.depositAmount != null ? '£${t.depositAmount!.toStringAsFixed(0)}' : '—', p: p),
            if (t.weeklyRent != null) ...[
              const SizedBox(height: 6),
              _FinanceLine(label: 'Weekly', value: '£${t.weeklyRent!.toStringAsFixed(0)}', p: p),
            ],
          ]),
        ]),

        // ── Deposit protection status (tappable → open deposit sheet) ────────
        if ((t.depositAmount ?? 0) > 0) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: canUploadDocs ? () => showRequestHoldingDepositSheet(context, tenancy: tenancy) : null,
            child: _DepositProtectionRow(tenancy: t, p: p),
          ),
        ],

        const SizedBox(height: 16),
        Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
        const SizedBox(height: 14),

        // ── Dates ─────────────────────────────────────────────────────────
        _DateRows(tenancy: t),

        // ── Tenants section (hidden when pending — application section covers it) ─
        if (!(canUploadDocs && t.status == 'pending')) ...[
        const SizedBox(height: 14),
        Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Row(children: [
          Text('Tenants', style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const Spacer(),
          if (canUploadDocs)
            GestureDetector(
              onTap: () => showInviteTenantSheet(context, tenancy: tenancy),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.blue.withValues(alpha: 0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_add_outlined, size: 11, color: p.blue),
                  const SizedBox(width: 4),
                  Text('Add', style: TextStyle(color: p.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        if (t.tenants.isNotEmpty)
          ...t.tenants.map((tenant) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TenantRow(tenant: tenant, tenancy: t),
          ))
        else if (t.invitedEmail != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: p.amber.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.amber.withValues(alpha: 0.2))),
            child: Row(children: [
              Icon(Icons.schedule_rounded, size: 14, color: p.amber),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Invite pending', style: TextStyle(color: p.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(t.invitedEmail!, style: TextStyle(color: p.muted, fontSize: 11)),
              ])),
            ]),
          )
        else
          GestureDetector(
            onTap: () => showInviteTenantSheet(context, tenancy: tenancy),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border, width: 1),
                boxShadow: p.cardShadow),
              child: Row(children: [
                Icon(Icons.person_add_outlined, size: 16, color: p.muted),
                const SizedBox(width: 10),
                Text('No tenant linked — tap to add',
                  style: TextStyle(color: p.muted, fontSize: 13)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 16, color: p.muted),
              ]),
            ),
          ),

        ], // end tenants section guard

        // ── RTR status row (always visible, tap to view/complete) ────────
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showRtrSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: needsRtr
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.07)
                  : p.green.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: needsRtr
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                    : p.green.withValues(alpha: 0.25),
              ),
            ),
            child: Row(children: [
              Icon(
                needsRtr ? Icons.badge_outlined : Icons.verified_user_outlined,
                size: 14,
                color: needsRtr ? const Color(0xFFF59E0B) : p.green,
              ),
              const SizedBox(width: 8),
              Expanded(child: needsRtr
                  ? const Text('Right to Rent check required',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w600))
                  : Row(children: [
                      Text('Right to Rent verified',
                          style: TextStyle(color: p.green, fontSize: 12, fontWeight: FontWeight.w600)),
                      if (t.rtrCheckDate != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${_formatDate(t.rtrCheckDate!)}',
                          style: TextStyle(color: p.muted, fontSize: 11),
                        ),
                      ],
                    ])),
              Icon(Icons.chevron_right_rounded, size: 14,
                  color: needsRtr ? const Color(0xFFF59E0B) : p.green),
            ]),
          ),
        ),

        // RTR re-check due alert (time-limited leave >12 months ago)
        if (rtrRecheckDue) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.refresh_rounded, size: 14,
                color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Right to Rent re-check due',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Text('Check was ${DateTime.now().difference(t.rtrCheckDate!).inDays ~/ 30}mo ago',
                style: const TextStyle(
                  color: Color(0xFFF59E0B), fontSize: 10)),
            ]),
          ),
        ],

        // ── Actions ───────────────────────────────────────────────────────
        if (canUploadDocs) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
          const SizedBox(height: 4),

          _ActionRow(icon: Icons.assignment_outlined,    label: 'Inspection',  subtitle: 'Check-in report', onTap: () => _launchInspection(context)),
          _ActionRow(icon: Icons.payments_outlined,      label: 'Rent Ledger', subtitle: 'Payment history', onTap: () => showRentLedgerSheet(context, tenancy: tenancy)),
          _ActionRow(
            icon: Icons.account_balance_outlined,
            label: 'Deposit',
            subtitle: hasProtection
                ? 'Protected · ${t.depositScheme!.toUpperCase()}'
                : 'Not yet protected',
            subtitleColor: hasProtection ? null : const Color(0xFFF59E0B),
            onTap: () => showRequestHoldingDepositSheet(context, tenancy: tenancy),
          ),
          _ActionRow(icon: Icons.manage_search_outlined, label: 'Full Details', onTap: () => showTenancyDetailsSheet(context, tenancy: tenancy)),
          if (onViewCompliance != null)
            _ActionRow(icon: Icons.verified_user_outlined, label: 'Compliance', onTap: onViewCompliance!),

          if (tenancy.status == 'active' || tenancy.status == 'notice_given') ...[
            const SizedBox(height: 4),
            Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
            const SizedBox(height: 4),
            _ActionRow(icon: Icons.gavel_rounded,          label: 'Serve Notice', onTap: () => showServeNoticeSheet(context, tenancy: tenancy),  accent: const Color(0xFFF59E0B)),
            _ActionRow(icon: Icons.meeting_room_outlined,  label: 'End Tenancy',  onTap: () => showEndTenancySheet(context, tenancy: tenancy),   accent: const Color(0xFFEF4444)),
          ],

          const SizedBox(height: 4),
        ],

        // ── Delete ────────────────────────────────────────────────────────
        if (onDelete != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _confirmDelete(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Delete tenancy',
                  style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 2),
      ]),
    );
  }

  void _launchInspection(BuildContext context) =>
      showCheckInReportSheet(context, tenancy: tenancy);

  void _showRtrSheet(BuildContext context) =>
      showRightToRentSheet(context, tenancy: tenancy);

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showAbodeConfirmDialog(
      context,
      title: 'Delete tenancy',
      body: 'This removes all tenants from this property and cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) onDelete?.call();
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Finance line ─────────────────────────────────────────────────────────────
class _FinanceLine extends StatelessWidget {
  final String label, value;
  final AbodePalette p;
  const _FinanceLine({required this.label, required this.value, required this.p});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$label  ', style: TextStyle(color: p.muted, fontSize: 12)),
    Text(value, style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}

// ─── Deposit protection status row ───────────────────────────────────────────
class _DepositProtectionRow extends StatelessWidget {
  final Tenancy tenancy;
  final AbodePalette p;
  const _DepositProtectionRow({required this.tenancy, required this.p});

  @override
  Widget build(BuildContext context) {
    final scheme = tenancy.depositScheme;
    final ref    = tenancy.depositRef;
    // Deposit is only considered protected when scheme AND reference are both provided
    final hasProtection = scheme != null && scheme.isNotEmpty &&
                          ref != null && ref.isNotEmpty;

    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (hasProtection ? p.green : p.amber).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (hasProtection ? p.green : p.amber).withValues(alpha: 0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            hasProtection ? Icons.shield_outlined : Icons.warning_amber_rounded,
            size: 11,
            color: hasProtection ? p.green : p.amber),
          const SizedBox(width: 4),
          Text(
            hasProtection
              ? 'Protected · ${scheme!.toUpperCase()} · $ref'
              : 'Deposit not yet protected',
            style: TextStyle(
              color: hasProtection ? p.green : p.amber,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

// ─── Unprotected deposit warning ─────────────────────────────────────────────
class _UnprotectedDepositBanner extends StatelessWidget {
  final Tenancy tenancy;
  final AbodePalette p;
  const _UnprotectedDepositBanner({required this.tenancy, required this.p});

  @override
  Widget build(BuildContext context) {
    final depositStr = tenancy.depositAmount != null
        ? '£${tenancy.depositAmount!.toStringAsFixed(0)}'
        : 'the deposit';
    return GestureDetector(
      onTap: () => showTenancyDetailsSheet(context, tenancy: tenancy),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: p.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.amber.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: p.amber),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Deposit of $depositStr not yet protected. Legally required within 30 days.',
            style: TextStyle(color: p.amber, fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
          )),
          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: p.amber),
        ]),
      ),
    );
  }
}

// ─── Date rows ────────────────────────────────────────────────────────────────
class _DateRows extends StatelessWidget {
  final Tenancy tenancy;
  const _DateRows({required this.tenancy});

  String _fmt(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final t = tenancy;
    final rows = <({IconData icon, String label, String value, Color color})>[];

    if (t.moveInDate != null) {
      final dt = DateTime.tryParse(t.moveInDate!);
      if (dt != null) rows.add((icon: Icons.login_outlined, label: 'Move-in',    value: _fmt(dt),    color: p.green));
    }
    if (t.endDate != null) {
      final days = t.endDate!.difference(DateTime.now()).inDays;
      final col  = days < 0 ? p.red : days <= 30 ? p.amber : p.sub;
      final suffix = days < 0 ? ' · expired' : days <= 60 ? ' · ${days}d' : '';
      rows.add((icon: Icons.logout_outlined, label: 'End date', value: '${_fmt(t.endDate!)}$suffix', color: col));
    }
    if (t.nextRentReviewDate != null) {
      final days = t.nextRentReviewDate!.difference(DateTime.now()).inDays;
      rows.add((icon: Icons.trending_up_rounded, label: 'Rent review',
        value: '${_fmt(t.nextRentReviewDate!)} · ${days}d', color: days <= 60 ? p.amber : p.sub));
    }
    if (t.minTenancyLength != null) {
      rows.add((icon: Icons.timer_outlined, label: 'Min term',
        value: '${t.minTenancyLength} months', color: p.sub));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: rows.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Icon(r.icon, size: 13, color: r.color),
          const SizedBox(width: 9),
          Text(r.label, style: TextStyle(color: p.muted, fontSize: 13)),
          const Spacer(),
          Text(r.value, style: TextStyle(color: r.color, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      )).toList(),
    );
  }
}

// ─── Tenant row ───────────────────────────────────────────────────────────────
class _TenantRow extends StatelessWidget {
  final TenantProfile tenant;
  final Tenancy? tenancy;
  const _TenantRow({required this.tenant, this.tenancy});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final active = tenant.status == 'active';
    final initials = (tenant.fullName ?? '?')
        .split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return GestureDetector(
      onTap: tenancy != null
          ? () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _TenantDetailSheet(tenant: tenant, tenancy: tenancy!),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: active ? p.green.withValues(alpha: 0.12) : p.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? p.green.withValues(alpha: 0.2) : p.border)),
            child: Center(child: Text(initials,
              style: TextStyle(color: active ? p.green : p.muted, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tenant.fullName ?? '—',
              style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
            if (tenant.email?.isNotEmpty == true)
              Text(tenant.email!, style: TextStyle(color: p.muted, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: active ? p.green.withValues(alpha: 0.1) : p.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? p.green.withValues(alpha: 0.2) : p.amber.withValues(alpha: 0.2))),
            child: Text(active ? 'Active' : 'Pending',
              style: TextStyle(color: active ? p.green : p.amber, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          if (tenancy != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 14, color: p.muted),
          ],
        ]),
      ),
    );
  }
}

// ─── Tenant detail sheet ──────────────────────────────────────────────────────
class _TenantDetailSheet extends StatelessWidget {
  final TenantProfile tenant;
  final Tenancy tenancy;
  const _TenantDetailSheet({required this.tenant, required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final t = tenancy;
    final fmt = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy');
    final active = tenant.status == 'active';
    final initials = (tenant.fullName ?? '?')
        .split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Container(
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
              decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)),
            )),

            // Profile header
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: active ? p.green.withValues(alpha: 0.12) : p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: active ? p.green.withValues(alpha: 0.2) : p.border)),
                child: Center(child: Text(initials,
                  style: TextStyle(color: active ? p.green : p.muted, fontSize: 18, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tenant.fullName ?? '—',
                  style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                if (tenant.email?.isNotEmpty == true)
                  Text(tenant.email!, style: TextStyle(color: p.muted, fontSize: 13)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? p.green.withValues(alpha: 0.1) : p.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? p.green.withValues(alpha: 0.2) : p.amber.withValues(alpha: 0.2))),
                child: Text(active ? 'Active' : 'Pending',
                  style: TextStyle(color: active ? p.green : p.amber, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),

            const SizedBox(height: 20),
            Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
            const SizedBox(height: 16),

            // Application details (if submitted)
            if (t.offerSubmittedAt != null || t.tenantEmploymentStatus != null) ...[
              Text('APPLICATION', style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (t.offerSubmittedAt != null) ...[
                    _DetailRow('Submitted', dateFmt.format(t.offerSubmittedAt!), p),
                    const SizedBox(height: 8),
                  ],
                  if (t.tenantEmploymentStatus != null) ...[
                    _DetailRow('Employment', _fmtEmployment(t.tenantEmploymentStatus!), p),
                    const SizedBox(height: 8),
                  ],
                  if (t.tenantAnnualIncome != null) ...[
                    _DetailRow('Annual income', fmt.format(t.tenantAnnualIncome!), p),
                    const SizedBox(height: 8),
                  ],
                  if (t.tenantMoveInPreference != null)
                    _DetailRow('Preferred move-in', dateFmt.format(t.tenantMoveInPreference!), p),
                  if (t.tenantMessage != null && t.tenantMessage!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text('"${t.tenantMessage}"',
                      style: TextStyle(color: p.sub, fontSize: 13, fontStyle: FontStyle.italic, height: 1.5)),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
            ],

            // Referencing
            Text('REFERENCING', style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            _buildReferencingCard(context, p),

            // RTR document
            if (t.rtrDocumentUrl != null && t.rtrDocumentUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('RIGHT TO RENT', style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              _buildRtrCard(context, p),
            ],

            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _buildReferencingCard(BuildContext context, AbodePalette p) {
    final status = tenancy.referencingStatus;
    final (Color color, IconData icon, String title, String subtitle) = switch (status) {
      'not_started' => (p.amber, Icons.fact_check_outlined, 'Not started', 'Referencing has not been requested yet.'),
      'in_progress' => (const Color(0xFF3B82F6), Icons.hourglass_top_rounded, 'In progress', 'Goodlord are checking credit, employment, and previous landlord references.'),
      'passed'      => (p.green,  Icons.verified_rounded,      'Passed',          'All checks passed.'),
      'conditional' => (p.amber,  Icons.warning_amber_rounded,  'Conditional pass', 'Some concerns were flagged. Review the report before deciding.'),
      'failed'      => (p.red,    Icons.cancel_outlined,        'Failed',           'The tenant did not pass referencing.'),
      _             => (p.muted,  Icons.help_outline,           status,             ''),
    };

    final dateFmt = DateFormat('d MMM yyyy');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(title,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700))),
          if (tenancy.referencingCompletedAt != null)
            Text(dateFmt.format(tenancy.referencingCompletedAt!),
              style: TextStyle(color: p.muted, fontSize: 11)),
        ]),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: p.sub, fontSize: 12, height: 1.4)),
        ],
        if (tenancy.homepplApplicationId != null) ...[
          const SizedBox(height: 6),
          Text('Ref: ${tenancy.homepplApplicationId}',
            style: TextStyle(color: p.muted, fontSize: 11)),
        ],
        if (tenancy.homepplReportUrl != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(tenancy.homepplReportUrl!);
              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                SizedBox(width: 6),
                Text('View report', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildRtrCard(BuildContext context, AbodePalette p) {
    final docType = tenancy.rtrTenantDocType ?? 'Document';
    final verified = tenancy.rtrStatus == 'completed';
    final color = verified ? p.green : p.amber;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(Icons.badge_outlined, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(docType, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(verified ? 'Verified by landlord' : 'Uploaded — awaiting verification',
            style: TextStyle(color: p.sub, fontSize: 11)),
        ])),
        if (tenancy.rtrDocumentUrl != null)
          GestureDetector(
            onTap: () async {
              final url = Supabase.instance.client.storage
                  .from('compliance-docs')
                  .getPublicUrl(tenancy.rtrDocumentUrl!);
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }

  String _fmtEmployment(String raw) => switch (raw) {
    'employed'      => 'Employed',
    'self_employed' => 'Self-employed',
    'student'       => 'Student',
    'unemployed'    => 'Unemployed',
    'retired'       => 'Retired',
    _               => raw,
  };
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final AbodePalette p;
  const _DetailRow(this.label, this.value, this.p);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$label:', style: TextStyle(color: p.muted, fontSize: 13)),
    const SizedBox(width: 8),
    Expanded(child: Text(value,
      style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600),
      textAlign: TextAlign.end)),
  ]);
}

// ─── Action row ───────────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;
  final Color? accent;
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.subtitle, this.subtitleColor, this.accent});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final fg = accent ?? p.sub;
    final isDestructive = accent != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        decoration: isDestructive
            ? BoxDecoration(border: Border(left: BorderSide(color: fg.withValues(alpha: 0.5), width: 2)))
            : null,
        child: Row(children: [
          if (isDestructive) const SizedBox(width: 10),
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500)),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(
                color: subtitleColor ?? p.muted,
                fontSize: 11,
                fontWeight: subtitleColor != null ? FontWeight.w600 : FontWeight.w400,
              )),
          ])),
          Icon(Icons.chevron_right_rounded, size: 16, color: fg.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}

// ─── Spec chip ────────────────────────────────────────────────────────────────
class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SpecChip(this.icon, this.label);

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

// ─── Application review (landlord side, pending tenancy) ─────────────────────
// Compact row — amber "awaiting" or green "received" + View button
class _ApplicationReviewSection extends StatelessWidget {
  final Tenancy tenancy;
  final WidgetRef ref;
  final AbodePalette p;
  const _ApplicationReviewSection({required this.tenancy, required this.ref, required this.p});

  @override
  Widget build(BuildContext context) {
    final submitted = tenancy.offerSubmittedAt != null;
    final color = submitted ? p.green : p.amber;
    final icon  = submitted ? Icons.person_outline : Icons.hourglass_empty_rounded;
    final label = submitted ? 'Application received' : 'Awaiting application';
    final sub   = submitted
        ? (tenancy.tenant?.fullName ?? tenancy.invitedEmail ?? '')
        : (tenancy.invitedEmail != null ? 'Invite sent to ${tenancy.invitedEmail}' : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          if (sub.isNotEmpty)
            Text(sub, style: TextStyle(color: p.muted, fontSize: 11)),
        ])),
        if (submitted) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showApplicationSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('View',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    );
  }

  void _showApplicationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplicationDetailSheet(tenancy: tenancy, ref: ref),
    );
  }
}

// Full-detail sheet shown when landlord taps "View"
class _ApplicationDetailSheet extends StatefulWidget {
  final Tenancy tenancy;
  final WidgetRef ref;
  const _ApplicationDetailSheet({required this.tenancy, required this.ref});
  @override
  State<_ApplicationDetailSheet> createState() => _ApplicationDetailSheetState();
}

class _ApplicationDetailSheetState extends State<_ApplicationDetailSheet> {
  bool _accepting = false;
  bool _declining = false;

  Tenancy get t => widget.tenancy;

  @override
  Widget build(BuildContext context) {
    final p       = AbodePalette.of(context);
    final fmt     = NumberFormat.currency(symbol: '£', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy');

    return Container(
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
              decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)),
            )),

            // Header
            Text('Application',
                style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 2),
            Text(t.addressLine1, style: TextStyle(color: p.sub, fontSize: 13)),
            const SizedBox(height: 20),

            // Applicant
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
                    color: p.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_outline, color: p.green, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.tenant?.fullName ?? t.invitedEmail ?? 'Applicant',
                      style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  if (t.offerSubmittedAt != null)
                    Text('Applied ${dateFmt.format(t.offerSubmittedAt!)}',
                        style: TextStyle(color: p.sub, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Received',
                      style: TextStyle(color: p.green, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Details card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (t.tenantEmploymentStatus != null) ...[
                  _AppRow('Employment', _fmtEmployment(t.tenantEmploymentStatus!), p),
                  const SizedBox(height: 10),
                ],
                if (t.tenantAnnualIncome != null) ...[
                  _AppRow('Annual income', fmt.format(t.tenantAnnualIncome!), p),
                  const SizedBox(height: 10),
                ],
                if (t.tenantMoveInPreference != null) ...[
                  _AppRow('Preferred move-in', dateFmt.format(t.tenantMoveInPreference!), p),
                ],
                if (t.tenantMessage != null && t.tenantMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('"${t.tenantMessage}"',
                      style: TextStyle(color: p.sub, fontSize: 13, fontStyle: FontStyle.italic, height: 1.5)),
                ],
              ]),
            ),
            const SizedBox(height: 20),

            // ── Referencing section ───────────────────────────────────────────
            _ReferencingBlock(tenancy: t, ref: widget.ref, p: p,
                onAccept: _accept, onDecline: _decline,
                accepting: _accepting, declining: _declining),
          ]),
        ),
      ),
    );
  }

  String _fmtEmployment(String raw) => switch (raw) {
    'employed'      => 'Employed',
    'self_employed' => 'Self-employed',
    'student'       => 'Student',
    'unemployed'    => 'Unemployed',
    'retired'       => 'Retired',
    _               => raw,
  };

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final ok = await widget.ref.read(landlordOfferDecisionProvider.notifier).accept(t.id);
    if (mounted) {
      if (ok) Navigator.pop(context);
      else setState(() => _accepting = false);
    }
  }

  Future<void> _decline() async {
    final p = AbodePalette.of(context);
    final confirmed = await showAbodeConfirmDialog(
      context,
      title: 'Decline application?',
      body: 'This will notify the applicant that their application was unsuccessful.',
      confirmLabel: 'Decline',
      isDestructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (confirmed != true) return;
    setState(() => _declining = true);
    final ok = await widget.ref.read(landlordOfferDecisionProvider.notifier).decline(t.id);
    if (mounted) {
      if (ok) Navigator.pop(context);
      else setState(() => _declining = false);
    }
  }
}

// ─── Referencing block ────────────────────────────────────────────────────────
class _ReferencingBlock extends StatefulWidget {
  final Tenancy tenancy;
  final WidgetRef ref;
  final AbodePalette p;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final bool accepting;
  final bool declining;
  const _ReferencingBlock({
    required this.tenancy, required this.ref, required this.p,
    required this.onAccept, required this.onDecline,
    required this.accepting, required this.declining,
  });
  @override
  State<_ReferencingBlock> createState() => _ReferencingBlockState();
}

class _ReferencingBlockState extends State<_ReferencingBlock> {
  bool _requesting = false;

  AbodePalette get p => widget.p;
  Tenancy get t => widget.tenancy;

  String get _refStatus => t.referencingStatus;
  bool get _canAccept =>
      _refStatus == 'passed' || _refStatus == 'conditional';

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Referencing status card ──────────────────────────────────────
      _buildReferencingCard(),
      const SizedBox(height: 16),

      // ── Accept (only enabled after referencing passes) ───────────────
      SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: (widget.accepting || widget.declining || !_canAccept)
              ? null
              : widget.onAccept,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _canAccept && !widget.accepting && !widget.declining
                  ? p.green
                  : p.border,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _canAccept && !widget.accepting ? [
                BoxShadow(color: p.green.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4)),
              ] : null,
            ),
            alignment: Alignment.center,
            child: widget.accepting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _canAccept ? 'Accept Application' : 'Complete referencing to accept',
                    style: TextStyle(
                      color: _canAccept ? Colors.white : p.muted,
                      fontSize: 15, fontWeight: FontWeight.w700,
                    )),
          ),
        ),
      ),
      const SizedBox(height: 10),

      // ── Decline ──────────────────────────────────────────────────────
      SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: (widget.accepting || widget.declining) ? null : widget.onDecline,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: p.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.red.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: widget.declining
                ? SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: p.red, strokeWidth: 2))
                : Text('Decline application',
                    style: TextStyle(color: p.red, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    ]);
  }

  Widget _buildReferencingCard() {
    switch (_refStatus) {
      case 'not_started':
        return _refCard(
          color: p.amber,
          icon: Icons.fact_check_outlined,
          title: 'Referencing required',
          subtitle: 'Run a credit & employment check via Goodlord before accepting.',
          action: GestureDetector(
            onTap: _requesting ? null : _requestReferencing,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: p.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _requesting
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Request',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        );

      case 'in_progress':
        return _refCard(
          color: const Color(0xFF3B82F6),
          icon: Icons.hourglass_top_rounded,
          title: 'Referencing in progress',
          subtitle: 'Goodlord are checking credit, employment, and previous landlord references. You\'ll be notified when complete.',
        );

      case 'passed':
        return _refCard(
          color: p.green,
          icon: Icons.verified_rounded,
          title: 'Referencing passed',
          subtitle: t.homepplApplicationId != null
              ? 'Ref: ${t.homepplApplicationId}'
              : 'All checks passed — you can now accept.',
          action: t.homepplReportUrl != null
              ? GestureDetector(
                  onTap: () => _openReport(t.homepplReportUrl!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('View report',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                )
              : null,
        );

      case 'conditional':
        return _refCard(
          color: p.amber,
          icon: Icons.warning_amber_rounded,
          title: 'Conditional pass',
          subtitle: 'Goodlord flagged some concerns. Review the report before deciding.',
          action: t.homepplReportUrl != null
              ? GestureDetector(
                  onTap: () => _openReport(t.homepplReportUrl!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('View report',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                )
              : null,
        );

      case 'failed':
        return _refCard(
          color: p.red,
          icon: Icons.cancel_outlined,
          title: 'Referencing failed',
          subtitle: 'The applicant did not pass referencing. We recommend declining.',
          action: t.homepplReportUrl != null
              ? GestureDetector(
                  onTap: () => _openReport(t.homepplReportUrl!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('View report',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                )
              : null,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _refCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: p.sub, fontSize: 11, height: 1.4)),
        ])),
        if (action != null) ...[
          const SizedBox(width: 10),
          action,
        ],
      ]),
    );
  }

  Future<void> _requestReferencing() async {
    setState(() => _requesting = true);
    try {
      final session = supabase.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final response = await supabase.functions.invoke(
        'start-referencing',
        body: {'tenancy_id': t.id},
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Unknown error');
      }

      widget.ref.invalidate(landlordTenanciesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showAbodeToast(context, 'Failed to start referencing: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _openReport(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _AppRow extends StatelessWidget {
  final String label, value;
  final AbodePalette p;
  const _AppRow(this.label, this.value, this.p);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$label:', style: TextStyle(color: p.muted, fontSize: 12)),
    const SizedBox(width: 6),
    Text(value, style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}

// ─── Status pill ──────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final color = switch (status) {
      'active'     => p.green,
      'pending'    => p.amber,
      'expired'    => p.red,
      'terminated' => p.red,
      _            => p.sub,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Text(
        switch (status) {
          'active'     => 'Active',
          'pending'    => 'Pending',
          'expired'    => 'Expired',
          'terminated' => 'Ended',
          _            => status[0].toUpperCase() + status.substring(1),
        },
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
    );
  }
}

