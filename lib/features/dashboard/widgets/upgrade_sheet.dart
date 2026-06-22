import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../models/plan.dart';
import '../providers/dashboard_providers.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

void showUpgradeSheet(
  BuildContext context, {
  PlanFeature? requiredFeature,
}) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ManagePlanSheet(requiredFeature: requiredFeature),
  );
}

const _abodeAccent = Color(0xFFA855F7);
const _proAccent   = Color(0xFFF59E0B);
const _freeAccent  = Color(0xFF22C55E);

Color _accentFor(AbodePlan plan) => switch (plan) {
  AbodePlan.free      => _freeAccent,
  AbodePlan.essential => _abodeAccent,
  AbodePlan.pro       => _proAccent,
};

// ─── Sheet ─────────────────────────────────────────────────────────────────
class _ManagePlanSheet extends ConsumerStatefulWidget {
  final PlanFeature? requiredFeature;
  const _ManagePlanSheet({this.requiredFeature});

  @override
  ConsumerState<_ManagePlanSheet> createState() => _ManagePlanSheetState();
}

class _ManagePlanSheetState extends ConsumerState<_ManagePlanSheet> {
  AbodePlan? _selected;
  bool       _saving          = false;
  int        _propCount       = 3; // for live price estimate
  String     _billingInterval = 'annual'; // 'monthly' or 'annual'

  @override
  Widget build(BuildContext context) {
    final p           = AbodePalette.of(context);
    final currentPlan = ref.watch(currentPlanProvider).valueOrNull ?? AbodePlan.free;
    final role        = ref.watch(currentProfileProvider).valueOrNull?.role ?? 'landlord';
    final isAgency    = role == 'agent';

    if (_selected == null && widget.requiredFeature != null) {
      _selected = widget.requiredFeature!.requiredPlan;
    }

    final isDowngrade = _selected != null && _selected!.index < currentPlan.index;
    final isCancel    = _selected == AbodePlan.free && currentPlan != AbodePlan.free;
    final isSame      = _selected == currentPlan;

    String ctaLabel() {
      if (_selected == null || isSame) return 'Select a plan';
      if (isCancel)    return 'Cancel subscription';
      if (isDowngrade) return 'Downgrade to ${_selected!.displayName}';
      return 'Upgrade to ${_selected!.displayName}';
    }

    Color ctaColor() {
      if (_selected == null || isSame) return p.border;
      if (isCancel || isDowngrade)     return const Color(0xFFEF4444);
      return _accentFor(_selected!);
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.requiredFeature != null
                        ? 'Unlock ${widget.requiredFeature!.label}'
                        : 'Choose your plan',
                    style: GoogleFonts.barlow(
                      color: p.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Currently on ${currentPlan.displayName} · First property always free',
                    style: TextStyle(color: p.sub, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Scrollable plan list
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  children: [
                    // ── Starter (current — compact) ─────────────────────
                    _buildStarterCard(p, currentPlan),
                    const SizedBox(height: 10),

                    // ── Abode (featured) ────────────────────────────────
                    _buildAbodeCard(p, currentPlan),

                    // ── Professional — agencies only ─────────────────────
                    if (isAgency) ...[
                      const SizedBox(height: 10),
                      _buildProCard(p, currentPlan),
                    ],
                  ],
                ),
              ),
            ),

            // Billing interval toggle (only shown when upgrading)
            if (!isDowngrade && !isCancel && _selected != null && _selected != AbodePlan.free)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _BillingToggle(
                  value: _billingInterval,
                  onChange: (v) => setState(() => _billingInterval = v),
                  propCount: _propCount,
                ),
              ),

            // Downgrade warning
            if (isDowngrade || isCancel)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.warning_amber_rounded,
                            size: 14, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCancel
                              ? 'You\'ll lose access to all paid features immediately. Data kept for 30 days.'
                              : _downgradeWarning(currentPlan, _selected!),
                          style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: GestureDetector(
                  onTap: (_selected == null || isSame || _saving)
                      ? null
                      : () => _handleChange(context, currentPlan, _selected!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: (_selected == null || isSame) ? p.border : ctaColor(),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: (_selected != null && !isSame) ? [
                        BoxShadow(
                          color: ctaColor().withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ] : null,
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            ctaLabel(),
                            style: GoogleFonts.barlow(
                              color: (_selected == null || isSame)
                                  ? p.sub
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Starter card — compact, de-emphasised (already owned) ─────────────────
  Widget _buildStarterCard(AbodePalette p, AbodePlan currentPlan) {
    final isCurrent  = currentPlan == AbodePlan.free;
    final isSelected = _selected == AbodePlan.free;

    return GestureDetector(
      onTap: isCurrent ? null : () => setState(() => _selected = AbodePlan.free),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEF4444).withValues(alpha: 0.05)
              : p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? _freeAccent.withValues(alpha: 0.4)
                : isSelected
                    ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                    : p.border,
            width: isCurrent || isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Starter',
                      style: GoogleFonts.barlow(
                        color: p.text, fontSize: 14,
                        fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  if (isCurrent) _Pill('ACTIVE', _freeAccent)
                  else if (isSelected) _Pill('DOWNGRADE', const Color(0xFFEF4444)),
                ]),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('£0',
                        style: GoogleFonts.barlow(
                          color: _freeAccent, fontSize: 22,
                          fontWeight: FontWeight.w800, height: 1)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('forever',
                          style: TextStyle(color: p.muted, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('1 property, core features included',
                    style: TextStyle(color: p.muted, fontSize: 11)),
              ],
            ),
          ),
          // Radio
          _Radio(
            selected: isSelected,
            current: isCurrent,
            accent: _freeAccent,
          ),
        ]),
      ),
    );
  }

  // ── Abode card — featured, with live price estimator ──────────────────────
  Widget _buildAbodeCard(AbodePalette p, AbodePlan currentPlan) {
    const plan       = AbodePlan.essential;
    final isCurrent  = currentPlan == plan;
    final isSelected = _selected == plan;
    final accent     = _abodeAccent;

    final estimatedMonthly = AbodePricing.monthlyAnnualBilled(_propCount);
    final estimateStr = estimatedMonthly == 0
        ? 'Free'
        : '${AbodePricing.fmt(estimatedMonthly)}/mo for $_propCount properties';

    const visibleFeatures = [
      'Unlimited properties — billed per property',
      'Contractor marketplace',
      'Full compliance suite & document vault',
      'Rent ledger & arrears alerts',
      'Legal notices (S13, S8) & Awaab\'s Law tracking',
    ];
    const hiddenCount = 4; // portfolio analytics, team seat, referencing fee, first property free

    return GestureDetector(
      onTap: isCurrent ? null : () => setState(() => _selected = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected || isCurrent
              ? accent.withValues(alpha: 0.07)
              : p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCurrent
                ? accent.withValues(alpha: 0.5)
                : isSelected
                    ? accent.withValues(alpha: 0.7)
                    : accent.withValues(alpha: 0.2),
            width: isCurrent || isSelected ? 1.5 : 1,
          ),
          boxShadow: (isSelected || isCurrent) ? [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + badge + radio
              Row(children: [
                Text('Abode',
                    style: GoogleFonts.barlow(
                      color: p.text, fontSize: 15,
                      fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (isCurrent)
                  _Pill('ACTIVE', accent)
                else
                  _Pill('MOST POPULAR', accent),
                const Spacer(),
                _Radio(selected: isSelected, current: isCurrent, accent: accent),
              ]),

              const SizedBox(height: 14),

              // Price + estimator
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('From £3.50',
                                style: GoogleFonts.barlow(
                                  color: accent,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  height: 1,
                                )),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('/ property · mo',
                                  style: TextStyle(color: p.muted, fontSize: 10)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Estimator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CounterBtn(
                                icon: Icons.remove,
                                onTap: _propCount > 1
                                    ? () => setState(() => _propCount--)
                                    : null,
                                accent: accent,
                                p: p,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '$_propCount prop${_propCount == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _CounterBtn(
                                icon: Icons.add,
                                onTap: _propCount < 50
                                    ? () => setState(() => _propCount++)
                                    : null,
                                accent: accent,
                                p: p,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '≈ $estimateStr · annual billing',
                          style: TextStyle(
                            color: p.sub,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
              const SizedBox(height: 12),

              // Features (capped list)
              ...visibleFeatures.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1.5),
                      child: Icon(Icons.check_rounded,
                          size: 13, color: p.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f,
                          style: TextStyle(
                              color: p.sub, fontSize: 12, height: 1.4)),
                    ),
                  ],
                ),
              )),

              // +N more
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+ $hiddenCount more features included',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Professional card ──────────────────────────────────────────────────────
  Widget _buildProCard(AbodePalette p, AbodePlan currentPlan) {
    const plan       = AbodePlan.pro;
    final isCurrent  = currentPlan == plan;
    final isSelected = _selected == plan;
    final accent     = _proAccent;

    return GestureDetector(
      onTap: isCurrent ? null : () => setState(() => _selected = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected || isCurrent
              ? accent.withValues(alpha: 0.06)
              : p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCurrent
                ? accent.withValues(alpha: 0.5)
                : isSelected
                    ? accent.withValues(alpha: 0.7)
                    : p.border,
            width: isCurrent || isSelected ? 1.5 : 1,
          ),
          boxShadow: (isSelected || isCurrent) ? [
            BoxShadow(
              color: accent.withValues(alpha: 0.1),
              blurRadius: 20, offset: const Offset(0, 5),
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + badge + auto-unlock note + radio
            Row(children: [
              Text('Professional',
                  style: GoogleFonts.barlow(
                    color: p.text, fontSize: 15,
                    fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              if (isCurrent)
                _Pill('ACTIVE', accent)
              else
                _Pill('AGENCIES & SCALE', accent),
              const Spacer(),
              _Radio(selected: isSelected, current: isCurrent, accent: accent),
            ]),

            const SizedBox(height: 10),

            // Auto-unlock callout
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 13, color: accent),
                  const SizedBox(width: 5),
                  Text('Auto-unlocks at 20+ properties',
                      style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('From £3.50',
                    style: GoogleFonts.barlow(
                      color: accent, fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5, height: 1,
                    )),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('/ property · mo',
                      style: TextStyle(color: p.muted, fontSize: 10)),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: p.border.withValues(alpha: 0.5)),
            const SizedBox(height: 10),

            // Differentiators only
            _proFeature(p, accent,
                icon: Icons.layers_rounded,
                label: 'Everything in Abode',
                italic: true),
            _proFeature(p, accent, label: 'White-label & custom branding'),
            _proFeature(p, accent, label: 'API access'),
            _proFeature(p, accent, label: 'Priority support — same-day response'),
          ],
        ),
      ),
    );
  }

  Widget _proFeature(AbodePalette p, Color accent,
      {required String label, IconData? icon, bool italic = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(icon ?? Icons.check_rounded,
                size: 13,
                color: italic ? accent : p.green),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: p.sub,
                    fontSize: 12,
                    height: 1.4,
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal)),
          ),
        ],
      ),
    );
  }

  String _downgradeWarning(AbodePlan from, AbodePlan to) {
    final lost = PlanFeature.values
        .where((f) => from.can(f) && !to.can(f))
        .map((f) => f.label)
        .toList();
    if (lost.isEmpty) return 'Your plan will change at the end of the billing period.';
    return 'You\'ll lose: ${lost.join(', ')}. Changes take effect at end of billing period.';
  }

  Future<void> _handleChange(
      BuildContext context, AbodePlan current, AbodePlan next) async {
    final isDowngrade = next.index < current.index;

    if (isDowngrade) {
      final confirmed = await _confirmDowngrade(context, current, next);
      if (!confirmed) return;
      await _openCustomerPortal(context);
      return;
    }

    setState(() => _saving = true);
    try {
      final url = await ref
          .read(createStripeCheckoutProvider.notifier)
          .createSession(interval: _billingInterval);
      if (url == null) throw Exception('No checkout URL');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (context.mounted) {
        showAbodeToast(context, 'Could not open checkout. Try again.', isError: true);
      }
    }
  }

  Future<void> _openCustomerPortal(BuildContext context) async {
    setState(() => _saving = true);
    try {
      final url = await ref.read(openCustomerPortalProvider.notifier).getUrl();
      if (url == null) throw Exception('No portal URL');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (context.mounted) {
        showAbodeToast(context, 'Could not open billing portal. Try again.', isError: true);
      }
    }
  }

  Future<bool> _confirmDowngrade(
      BuildContext context, AbodePlan from, AbodePlan to) async {
    final p        = AbodePalette.of(context);
    final isCancel = to == AbodePlan.free;
    return await showAbodeConfirmDialog(
          context,
          title: isCancel ? 'Cancel subscription?' : 'Downgrade to ${to.displayName}?',
          body: isCancel
              ? "You'll immediately lose access to all paid features. Your data is kept for 30 days."
              : _downgradeWarning(from, to),
          confirmLabel: isCancel ? 'Cancel subscription' : 'Downgrade',
          cancelLabel: 'Keep ${from.displayName}',
          isDestructive: true,
          icon: Icons.subscriptions_outlined,
        ) ??
        false;
  }
}

// ─── Radio indicator ──────────────────────────────────────────────────────
class _Radio extends StatelessWidget {
  final bool selected;
  final bool current;
  final Color accent;
  const _Radio({required this.selected, required this.current, required this.accent});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 20, height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? accent
              : current
                  ? accent.withValues(alpha: 0.15)
                  : Colors.transparent,
          border: Border.all(
            color: selected
                ? accent
                : current
                    ? accent.withValues(alpha: 0.5)
                    : const Color(0xFF3A3A3E),
            width: 1.5,
          ),
        ),
        child: (selected || current)
            ? Icon(Icons.check, size: 12,
                color: selected ? Colors.white : accent)
            : null,
      );
}

// ─── Counter button ───────────────────────────────────────────────────────
class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final AbodePalette p;
  const _CounterBtn({
    required this.icon,
    required this.onTap,
    required this.accent,
    required this.p,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: onTap != null
                ? accent.withValues(alpha: 0.15)
                : p.border.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              size: 14,
              color: onTap != null ? accent : p.muted),
        ),
      );
}

// ─── Pill badge ───────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      );
}

// ─── Billing interval toggle ──────────────────────────────────────────────
class _BillingToggle extends StatelessWidget {
  final String value;
  final void Function(String) onChange;
  final int propCount;
  const _BillingToggle({
    required this.value,
    required this.onChange,
    required this.propCount,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    const accent = _abodeAccent;

    final monthlyPrice  = AbodePricing.monthlyBilled(propCount);
    final annualMonthly = AbodePricing.monthlyAnnualBilled(propCount);
    final saving = monthlyPrice > 0
        ? ((monthlyPrice - annualMonthly) / monthlyPrice * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(children: [
        _ToggleOption(
          label: 'Annual',
          sublabel: saving > 0 ? 'Save $saving%' : null,
          selected: value == 'annual',
          accent: accent,
          p: p,
          onTap: () => onChange('annual'),
        ),
        _ToggleOption(
          label: 'Monthly',
          sublabel: '+20%',
          selected: value == 'monthly',
          accent: accent,
          p: p,
          onTap: () => onChange('monthly'),
        ),
      ]),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final Color accent;
  final AbodePalette p;
  final VoidCallback onTap;
  const _ToggleOption({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.accent,
    required this.p,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: accent.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(children: [
          Text(label,
            style: TextStyle(
              color: selected ? accent : p.sub,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(sublabel!,
              style: TextStyle(
                color: selected
                    ? accent.withValues(alpha: 0.75)
                    : p.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              )),
          ],
        ]),
      ),
    ),
  );
}
