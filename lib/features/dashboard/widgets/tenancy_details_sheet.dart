import 'package:flow_app/core/widgets/adaptive_sheet.dart';
/// Sheet for editing tenancy metadata:
/// - Deposit scheme + reference
/// - PRS registration reference
/// - Referencing status
/// - Inspection history
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/homeppl_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

void showTenancyDetailsSheet(BuildContext context, {required Tenancy tenancy}) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TenancyDetailsSheet(tenancy: tenancy),
  );
}

// ─── Inspections provider ─────────────────────────────────────────────────────

final tenancyInspectionsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, tenancyId) async {
  try {
    final data = await supabase
        .from('inspections')
        .select('id, inspection_type, inspection_date, overall_condition, items, created_at')
        .eq('tenancy_id', tenancyId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return [];
  }
});

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _TenancyDetailsSheet extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  const _TenancyDetailsSheet({required this.tenancy});
  @override ConsumerState<_TenancyDetailsSheet> createState() => _State();
}

class _State extends ConsumerState<_TenancyDetailsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        // Handle + header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: p.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.home_work_outlined,
                    color: Color(0xFF3B82F6), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tenancy Details', style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800)),
                Text(widget.tenancy.shortAddress, style: TextStyle(color: p.muted, fontSize: 12)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: p.card, shape: BoxShape.circle, border: Border.all(color: p.border)),
                  child: Icon(Icons.close_rounded, size: 16, color: p.sub)),
              ),
            ]),
            const SizedBox(height: 14),
            TabBar(
              controller: _tabs,
              labelColor: p.blue,
              unselectedLabelColor: p.muted,
              indicatorColor: p.blue,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: p.border,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Compliance'),
                Tab(text: 'Referencing'),
                Tab(text: 'Inspections'),
              ],
            ),
          ]),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _ComplianceTab(tenancy: widget.tenancy, ref: ref, p: p),
            _ReferencingTab(tenancy: widget.tenancy, ref: ref, p: p),
            _InspectionsTab(tenancy: widget.tenancy, p: p),
          ]),
        ),
      ]),
    );
  }
}

// ─── Compliance tab: deposit ref + PRS ───────────────────────────────────────

class _ComplianceTab extends StatefulWidget {
  final Tenancy tenancy; final WidgetRef ref; final AbodePalette p;
  const _ComplianceTab({required this.tenancy, required this.ref, required this.p});
  @override State<_ComplianceTab> createState() => _ComplianceTabState();
}

class _ComplianceTabState extends State<_ComplianceTab> {
  late TextEditingController _depositRefCtrl;
  late TextEditingController _prsRefCtrl;
  late String _depositScheme;
  DateTime? _reviewDate;
  bool _saving = false;
  bool _registeringTds = false;

  static const _schemes = ['DPS', 'mydeposits', 'TDS'];

  @override
  void initState() {
    super.initState();
    _depositRefCtrl = TextEditingController(text: widget.tenancy.depositRef ?? '');
    _prsRefCtrl     = TextEditingController(text: widget.tenancy.prsRegistrationRef ?? '');
    _depositScheme  = widget.tenancy.depositScheme ?? 'DPS';
    if (!_schemes.contains(_depositScheme)) _depositScheme = 'DPS';
    _reviewDate     = widget.tenancy.tenancyReviewDate;
  }

  @override void dispose() { _depositRefCtrl.dispose(); _prsRefCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [

        // Deposit protection card (DPS / TDS / Reposit)
        _DepositProtectionCard(
          tenancy: widget.tenancy,
          p: p,
          ref: widget.ref,
          registeringTds: _registeringTds,
          onRegisterTds: _registerWithTds,
        ),
        const SizedBox(height: 20),

        // Deposit scheme
        _SectionTitle('Deposit Protection', p),
        const SizedBox(height: 10),
        _InfoCard(p: p, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scheme', style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: _schemes.map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _depositScheme = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _depositScheme == s ? p.green.withValues(alpha: 0.12) : p.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _depositScheme == s ? p.green.withValues(alpha: 0.4) : p.border,
                    width: _depositScheme == s ? 1.5 : 1)),
                child: Text(s, style: TextStyle(
                  color: _depositScheme == s ? p.green : p.sub,
                  fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          )).toList()),
          const SizedBox(height: 14),
          Text('Scheme reference', style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _TextField(ctrl: _depositRefCtrl, hint: 'e.g. DPS1234567', p: p),
          const SizedBox(height: 6),
          Text('Must be provided to tenant within 30 days of receiving deposit.',
            style: TextStyle(color: p.muted, fontSize: 11)),
          const SizedBox(height: 8),
          Text(
            'Abode records deposit protection details for reference only. '
            'Abode does not hold, protect, or act as custodian of any deposit. '
            'Landlords are solely responsible for registering the deposit with '
            'the chosen government-approved scheme within the required timeframe.',
            style: TextStyle(color: p.muted, fontSize: 11, height: 1.4)),
        ])),

        const SizedBox(height: 20),

        // PRS
        _SectionTitle('PRS Database Registration', p),
        const SizedBox(height: 10),
        _InfoCard(p: p, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.blue.withValues(alpha: 0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 13, color: p.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Required under the Renters\' Rights Act 2025. All landlords must register on the Private Rented Sector Database.',
                style: TextStyle(color: p.blue, fontSize: 11, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Registration reference', style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _TextField(ctrl: _prsRefCtrl, hint: 'e.g. PRS-2025-XXXXXX', p: p),
        ])),

        const SizedBox(height: 20),

        // Soft review date
        _SectionTitle('Tenancy Review Date', p),
        const SizedBox(height: 4),
        Text('A soft reminder — not a legal term. Helps you decide whether to have a conversation about the tenancy.',
          style: TextStyle(color: p.muted, fontSize: 12, height: 1.4)),
        const SizedBox(height: 10),
        _InfoCard(p: p, child: GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _reviewDate ?? DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) setState(() => _reviewDate = picked);
          },
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: p.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.event_note_rounded, size: 18, color: p.teal)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Review date', style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                _reviewDate != null
                    ? DateFormat('d MMM yyyy').format(_reviewDate!)
                    : 'Tap to set a date',
                style: TextStyle(
                  color: _reviewDate != null ? p.text : p.muted,
                  fontSize: 14, fontWeight: FontWeight.w500)),
            ])),
            if (_reviewDate != null)
              GestureDetector(
                onTap: () => setState(() => _reviewDate = null),
                child: Icon(Icons.clear_rounded, size: 18, color: p.muted)),
            if (_reviewDate == null)
              Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
          ]),
        )),

        const SizedBox(height: 24),

        // Save
        _SaveBtn(loading: _saving, onTap: _save, p: p),
      ],
    );
  }

  Future<void> _registerWithTds() async {
    setState(() => _registeringTds = true);
    try {
      final ok = await widget.ref
          .read(registerTdsDepositProvider.notifier)
          .register(widget.tenancy.id);
      if (mounted) {
        showAbodeToast(context, ok ? 'Deposit registered with TDS' : 'Registration failed — check TDS settings', isError: true);
      }
    } finally {
      if (mounted) setState(() => _registeringTds = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await supabase.from('tenancies').update({
        'deposit_scheme': _depositScheme,
        if (_depositRefCtrl.text.trim().isNotEmpty) 'deposit_ref': _depositRefCtrl.text.trim(),
        if (_prsRefCtrl.text.trim().isNotEmpty) 'prs_registration_ref': _prsRefCtrl.text.trim(),
        'tenancy_review_date': _reviewDate != null
            ? '${_reviewDate!.year}-${_reviewDate!.month.toString().padLeft(2, '0')}-${_reviewDate!.day.toString().padLeft(2, '0')}'
            : null,
      }).eq('id', widget.tenancy.id);

      widget.ref.invalidate(landlordTenanciesProvider);
      if (mounted) {
        showAbodeToast(context, 'Compliance details saved');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Deposit protection card ──────────────────────────────────────────────────

class _DepositProtectionCard extends ConsumerStatefulWidget {
  final Tenancy tenancy;
  final AbodePalette p;
  final WidgetRef ref;
  final bool registeringTds;
  final VoidCallback onRegisterTds;

  const _DepositProtectionCard({
    required this.tenancy,
    required this.p,
    required this.ref,
    required this.registeringTds,
    required this.onRegisterTds,
  });

  @override
  ConsumerState<_DepositProtectionCard> createState() => _DepositProtectionCardState();
}

class _DepositProtectionCardState extends ConsumerState<_DepositProtectionCard> {
  bool _registeringDps     = false;
  bool _creatingReposit    = false;

  Future<void> _registerDps() async {
    setState(() => _registeringDps = true);
    try {
      final ok = await ref.read(registerDpsDepositProvider.notifier).register(widget.tenancy.id);
      if (mounted) {
        showAbodeToast(context, ok ? 'Deposit registered with DPS' : 'Registration failed — check DPS settings', isError: true);
      }
    } finally {
      if (mounted) setState(() => _registeringDps = false);
    }
  }

  Future<void> _createReposit() async {
    setState(() => _creatingReposit = true);
    try {
      final ok = await ref.read(createRepositPolicyProvider.notifier).create(widget.tenancy.id);
      if (mounted) {
        showAbodeToast(context, ok ? 'Reposit invitation sent to tenant' : 'Failed — check Reposit settings', isError: true);
      }
    } finally {
      if (mounted) setState(() => _creatingReposit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p        = widget.p;
    final tenancy  = widget.tenancy;
    final settings = ref.watch(platformSettingsProvider).valueOrNull ?? const PlatformSettings();
    final hasDeposit = (tenancy.depositAmount ?? 0) > 0;
    final method   = tenancy.depositProtectionMethod;

    // ── Already protected — show status banner ────────────────────────────
    if (method == 'tds' && tenancy.tdsStatus == 'protected') {
      return _ProtectedBanner(label: 'Protected with TDS', ref: tenancy.tdsProtectionRef, certUrl: tenancy.tdsCertUrl, p: p);
    }
    if (method == 'dps' && tenancy.dpsStatus == 'protected') {
      return _ProtectedBanner(label: 'Protected with DPS', ref: tenancy.dpsProtectionRef, certUrl: tenancy.dpsCertUrl, p: p);
    }
    if (method == 'reposit' && tenancy.repositStatus == 'active') {
      return _ProtectedBanner(label: 'Reposit policy active', ref: tenancy.repositPolicyRef, certUrl: null, p: p, icon: Icons.verified_user_rounded);
    }
    if (method == 'reposit' && tenancy.repositStatus == 'invited') {
      return _PendingBanner(label: 'Reposit — awaiting tenant sign-up', p: p);
    }
    if ((method == 'tds' && tenancy.tdsStatus == 'pending') ||
        (method == 'dps' && tenancy.dpsStatus == 'pending')) {
      return _PendingBanner(label: 'Deposit registration in progress…', p: p);
    }

    // ── Not yet protected ─────────────────────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Deposit Protection',
            style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          hasDeposit
              ? 'Choose how to protect the £${tenancy.depositAmount!.toStringAsFixed(0)} deposit.'
              : 'Set a deposit amount on this tenancy to enable protection.',
          style: TextStyle(color: p.sub, fontSize: 12, height: 1.4),
        ),

        if (hasDeposit) ...[
          const SizedBox(height: 16),

          // ── Track A: Traditional (DPS / TDS) ─────────────────────────
          _OptionRow(
            icon: Icons.account_balance_rounded,
            color: const Color(0xFF3B82F6),
            title: 'Traditional Deposit',
            subtitle: 'Scheme holds the money · DPS Custodial or TDS',
            enabled: settings.dpsEnabled || settings.tdsEnabled,
            comingSoonLabel: 'Partnership in progress',
            p: p,
            children: [
              if (settings.dpsEnabled)
                _ActionButton(
                  label: _registeringDps ? 'Registering…' : 'Register with DPS',
                  loading: _registeringDps,
                  color: const Color(0xFF3B82F6),
                  onTap: _registerDps,
                ),
              if (settings.tdsEnabled) ...[
                if (settings.dpsEnabled) const SizedBox(width: 8),
                _ActionButton(
                  label: widget.registeringTds ? 'Registering…' : 'Register with TDS',
                  loading: widget.registeringTds,
                  color: const Color(0xFF6366F1),
                  onTap: widget.onRegisterTds,
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // ── Track B: Deposit replacement (Reposit) ────────────────────
          _OptionRow(
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFF14B8A6),
            title: 'Deposit Replacement',
            subtitle: 'No cash upfront · Tenant pays small fee · Reposit',
            enabled: settings.repositEnabled,
            comingSoonLabel: 'Partnership in progress',
            p: p,
            children: [
              if (settings.repositEnabled)
                _ActionButton(
                  label: _creatingReposit ? 'Sending invite…' : 'Invite tenant via Reposit',
                  loading: _creatingReposit,
                  color: const Color(0xFF14B8A6),
                  onTap: _createReposit,
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Manual registration links ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Register directly with a scheme',
                style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('You can register manually on the scheme websites below, then enter the reference above.',
                style: TextStyle(color: p.muted, fontSize: 11, height: 1.4)),
              const SizedBox(height: 10),
              Row(children: [
                _SchemeLink(label: 'TDS', url: 'https://www.tds.gb.com', color: const Color(0xFF6366F1), p: p),
                const SizedBox(width: 8),
                _SchemeLink(label: 'DPS', url: 'https://www.depositprotection.com', color: const Color(0xFF3B82F6), p: p),
                const SizedBox(width: 8),
                _SchemeLink(label: 'mydeposits', url: 'https://www.mydeposits.co.uk', color: const Color(0xFF0EA5E9), p: p),
              ]),
              const SizedBox(height: 8),
              Text('Automatic verification coming soon',
                style: TextStyle(color: p.muted, fontSize: 10, fontStyle: FontStyle.italic)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ProtectedBanner extends StatelessWidget {
  final String label;
  final String? ref;
  final String? certUrl;
  final AbodePalette p;
  final IconData icon;

  const _ProtectedBanner({
    required this.label,
    required this.ref,
    required this.certUrl,
    required this.p,
    this.icon = Icons.verified_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF22C55E), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w700)),
          if (ref != null) Text('Ref: $ref', style: TextStyle(color: p.muted, fontSize: 11)),
        ])),
        if (certUrl != null)
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(certUrl!);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Certificate', style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final String label;
  final AbodePalette p;
  const _PendingBanner({required this.label, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        const Icon(Icons.hourglass_empty_rounded, color: Color(0xFFF59E0B), size: 18),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final String comingSoonLabel;
  final AbodePalette p;
  final List<Widget> children;

  const _OptionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.comingSoonLabel,
    required this.p,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled ? color.withValues(alpha: 0.04) : p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: enabled ? color.withValues(alpha: 0.2) : p.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: enabled ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: enabled ? color : p.muted, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
              color: enabled ? p.text : p.muted,
              fontSize: 13, fontWeight: FontWeight.w700)),
            Text(subtitle, style: TextStyle(color: p.muted, fontSize: 11)),
          ])),
          if (!enabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Coming soon', style: TextStyle(color: p.muted, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
        ]),
        if (enabled && children.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: children),
        ],
      ]),
    );
  }
}

class _SchemeLink extends StatelessWidget {
  final String label;
  final String url;
  final Color color;
  final AbodePalette p;
  const _SchemeLink({required this.label, required this.url, required this.color, required this.p});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(width: 3),
            Icon(Icons.open_in_new_rounded, size: 10, color: color),
          ]),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.loading,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 38,
        child: ElevatedButton.icon(
          icon: loading
              ? const SizedBox(width: 13, height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.shield_rounded, size: 14),
          label: Text(label, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          onPressed: loading ? null : onTap,
        ),
      ),
    );
  }
}

// ─── Referencing tab ──────────────────────────────────────────────────────────

class _ReferencingTab extends StatefulWidget {
  final Tenancy tenancy; final WidgetRef ref; final AbodePalette p;
  const _ReferencingTab({required this.tenancy, required this.ref, required this.p});
  @override State<_ReferencingTab> createState() => _ReferencingTabState();
}

class _ReferencingTabState extends State<_ReferencingTab> {
  late String _refStatus;
  bool _saving = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _refStatus = widget.tenancy.referencingStatus;
  }

  bool get _homepplActive => widget.tenancy.homepplApplicationId != null;
  bool get _canRequest =>
      !_homepplActive &&
      _refStatus == 'not_started' &&
      widget.tenancy.tenant != null;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [

        // ── Homeppl integration card ────────────────────────────────────
        _SectionTitle('Credit & Employment Referencing', p),
        const SizedBox(height: 10),
        _InfoCard(p: p, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Status row
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _refColor(_refStatus, p).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(_refIcon(_refStatus), color: _refColor(_refStatus, p), size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_refLabel(_refStatus),
                style: TextStyle(color: _refColor(_refStatus, p), fontSize: 14, fontWeight: FontWeight.w700)),
              Text(_homepplActive
                  ? 'Homeppl ref: ${widget.tenancy.homepplApplicationId}'
                  : 'Powered by Homeppl',
                style: TextStyle(color: p.muted, fontSize: 11),
                overflow: TextOverflow.ellipsis),
            ])),
            if (_refStatus == 'passed')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
                child: Text('Clear', style: TextStyle(color: p.green, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),

          // Report link
          if (widget.tenancy.homepplReportUrl != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(widget.tenancy.homepplReportUrl!);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: p.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.blue.withValues(alpha: 0.2))),
                child: Row(children: [
                  Icon(Icons.description_outlined, size: 14, color: p.blue),
                  const SizedBox(width: 8),
                  Text('View Homeppl Report', style: TextStyle(color: p.blue, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.open_in_new_rounded, size: 13, color: p.blue),
                ]),
              ),
            ),
          ],

          // Request button — shown when not yet requested
          if (_canRequest || (!_homepplActive && _refStatus == 'not_started')) ...[
            const SizedBox(height: 12),
            if (widget.tenancy.tenant == null)
              Text('Add a tenant to this tenancy before requesting referencing.',
                style: TextStyle(color: p.muted, fontSize: 12))
            else
              GestureDetector(
                onTap: _requesting ? null : _requestReferencing,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _requesting ? p.border : p.green,
                    borderRadius: BorderRadius.circular(10)),
                  child: Center(child: _requesting
                      ? SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: p.green, strokeWidth: 2))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.send_rounded, color: Colors.white, size: 15),
                          const SizedBox(width: 8),
                          const Text('Request Referencing via Homeppl',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ])),
                ),
              ),
            const SizedBox(height: 6),
            Text('Homeppl will contact the tenant directly. Results arrive automatically.',
              style: TextStyle(color: p.muted, fontSize: 11)),
          ],

          // Already requested — in progress state
          if (_homepplActive && _refStatus == 'in_progress') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.blue.withValues(alpha: 0.15))),
              child: Row(children: [
                SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(color: p.blue, strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(child: Text('Homeppl checks in progress — this will update automatically when complete.',
                  style: TextStyle(color: p.blue, fontSize: 12))),
              ]),
            ),
          ],
        ])),

        // ── Manual override ─────────────────────────────────────────────
        const SizedBox(height: 20),
        _SectionTitle('Manual Override', p),
        const SizedBox(height: 4),
        Text('Use if you\'ve referenced outside Abode and want to record the result.',
          style: TextStyle(color: p.muted, fontSize: 12)),
        const SizedBox(height: 10),
        _InfoCard(p: p, child: Column(children: [
          ...['not_started', 'in_progress', 'passed', 'failed'].map((status) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => setState(() => _refStatus = status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _refStatus == status ? _refColor(status, p).withValues(alpha: 0.07) : p.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _refStatus == status ? _refColor(status, p).withValues(alpha: 0.35) : p.border,
                    width: _refStatus == status ? 1.5 : 1)),
                child: Row(children: [
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: _refStatus == status ? _refColor(status, p) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: _refStatus == status ? _refColor(status, p) : p.muted)),
                    child: _refStatus == status
                        ? const Icon(Icons.check, color: Colors.white, size: 11) : null),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_refLabel(status), style: TextStyle(
                    color: _refStatus == status ? _refColor(status, p) : p.text,
                    fontSize: 13, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          )),
        ])),

        const SizedBox(height: 24),
        _SaveBtn(loading: _saving, onTap: _save, p: p),
      ],
    );
  }

  Color _refColor(String status, AbodePalette p) => switch (status) {
    'passed'      => p.green,
    'failed'      => p.red,
    'in_progress' => p.blue,
    'conditional' => p.amber,
    _             => p.muted,
  };

  IconData _refIcon(String status) => switch (status) {
    'passed'      => Icons.verified_rounded,
    'failed'      => Icons.cancel_outlined,
    'in_progress' => Icons.hourglass_top_rounded,
    'conditional' => Icons.warning_amber_rounded,
    _             => Icons.person_search_outlined,
  };

  String _refLabel(String status) => switch (status) {
    'passed'      => 'Passed',
    'failed'      => 'Failed',
    'in_progress' => 'In progress',
    'conditional' => 'Conditional pass',
    _             => 'Not started',
  };

  Future<void> _requestReferencing() async {
    final tenant = widget.tenancy.tenant;
    if (tenant == null) return;
    setState(() => _requesting = true);
    final result = await HomepplService.requestReferencing(
      tenancyId:       widget.tenancy.id,
      tenantEmail:     tenant.email ?? '',
      tenantFullName:  tenant.fullName ?? tenant.email ?? '',
      monthlyRent:     widget.tenancy.monthlyRent ?? 0,
      propertyAddress: widget.tenancy.addressOneLiner,
    );
    if (mounted) {
      setState(() {
        _requesting = false;
        if (result.ok) _refStatus = 'in_progress';
      });
      widget.ref.invalidate(landlordTenanciesProvider);
      showAbodeToast(context, result.ok
            ? 'Referencing requested — your team will be in touch with the tenant'
            : result.errorMessage ?? 'Request failed', isError: true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await supabase.from('tenancies').update({
        'referencing_status': _refStatus,
      }).eq('id', widget.tenancy.id);
      widget.ref.invalidate(landlordTenanciesProvider);
      if (mounted) {
        showAbodeToast(context, 'Referencing status updated');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Inspections tab ──────────────────────────────────────────────────────────

class _InspectionsTab extends ConsumerWidget {
  final Tenancy tenancy; final AbodePalette p;
  const _InspectionsTab({required this.tenancy, required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tenancyInspectionsProvider(tenancy.id));
    return async.when(
      loading: () => Center(child: CircularProgressIndicator(color: p.green, strokeWidth: 2)),
      error: (_, __) => Center(child: Text('Could not load inspections', style: TextStyle(color: p.muted))),
      data: (inspections) {
        if (inspections.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border)),
              child: Icon(Icons.assignment_outlined, color: p.muted, size: 26)),
            const SizedBox(height: 12),
            Text('No inspection reports', style: TextStyle(color: p.sub, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Start one from the tenancy card', style: TextStyle(color: p.muted, fontSize: 13)),
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: inspections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _InspectionRow(item: inspections[i], p: p),
        );
      },
    );
  }
}

class _InspectionRow extends StatelessWidget {
  final Map<String, dynamic> item; final AbodePalette p;
  const _InspectionRow({required this.item, required this.p});

  @override
  Widget build(BuildContext context) {
    final type      = item['inspection_type'] as String? ?? 'checkin';
    final isCheckIn = type == 'checkin';
    final color     = isCheckIn ? p.green : p.amber;
    final date      = item['inspection_date'] != null
        ? DateFormat('d MMM yyyy').format(DateTime.parse(item['inspection_date'] as String))
        : '—';
    final rooms     = (item['items'] as List?)?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(isCheckIn ? Icons.login_outlined : Icons.logout_outlined,
              color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isCheckIn ? 'Check-In Report' : 'Check-Out Report',
            style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600)),
          Text('$date · $rooms room${rooms == 1 ? "" : "s"} inspected',
            style: TextStyle(color: p.muted, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
          child: Text(isCheckIn ? 'Check-in' : 'Check-out',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

// ─── Shared ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text; final AbodePalette p;
  const _SectionTitle(this.text, this.p);
  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700));
}

class _InfoCard extends StatelessWidget {
  final AbodePalette p; final Widget child;
  const _InfoCard({required this.p, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: p.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: p.border)),
    child: child,
  );
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl; final String hint; final AbodePalette p;
  const _TextField({required this.ctrl, required this.hint, required this.p});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: TextStyle(color: p.text, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: p.muted, fontSize: 14),
      filled: true, fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.green, width: 1.5)),
      isDense: true),
  );
}

class _SaveBtn extends StatelessWidget {
  final bool loading; final VoidCallback onTap; final AbodePalette p;
  const _SaveBtn({required this.loading, required this.onTap, required this.p});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: p.green, borderRadius: BorderRadius.circular(14)),
        child: Center(child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Save Changes',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
      ),
    ),
  );
}
