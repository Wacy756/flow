import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import 'agency_onboarding.dart';
import 'contractor_onboarding.dart';
import 'landlord_onboarding.dart';
import 'tenant_onboarding.dart';

// ─── Role accent colours ──────────────────────────────────────────────────────
const kLandlordAccent   = Color(0xFF3B82F6);
const kAgencyAccent     = Color(0xFFA855F7);
const kContractorAccent = Color(0xFFF97316);

Color accentForRole(String role) => switch (role) {
  'landlord'   => kLandlordAccent,
  'agent'      => kAgencyAccent,
  'contractor' => kContractorAccent,
  _            => kLandlordAccent,
};

// ─── Entry point ──────────────────────────────────────────────────────────────
class OnboardingFlow extends ConsumerWidget {
  final UserProfile profile;
  final VoidCallback onComplete;
  const OnboardingFlow({
    super.key,
    required this.profile,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (profile.role) {
    'landlord'   => LandlordOnboarding(profile: profile, onComplete: onComplete),
    'tenant'     => TenantOnboarding(profile: profile, onComplete: onComplete),
    'agent'      => AgencyOnboarding(profile: profile, onComplete: onComplete),
    'contractor' => ContractorOnboarding(profile: profile, onComplete: onComplete),
    _            => TenantOnboarding(profile: profile, onComplete: onComplete),
  };
}

// ─── Shared save helper ───────────────────────────────────────────────────────
Future<void> saveOnboardingComplete({
  required String userId,
  required String? plan,
  String? agencyName,
  int? portfolioSize,
  String? teamSize,
}) async {
  await supabase.from('profiles').update({
    'onboarding_completed': true,
    'tos_accepted_at':      DateTime.now().toUtc().toIso8601String(),
    if (plan != null) 'selected_plan': plan,
    if (agencyName != null) 'agency_name': agencyName,
    if (portfolioSize != null) 'portfolio_size': portfolioSize,
    if (teamSize != null) 'team_size': teamSize,
  }).eq('id', userId);
}

// ─── Shared scaffold ──────────────────────────────────────────────────────────
class ObScaffold extends StatelessWidget {
  final int step;
  final int totalSteps;
  final Color accent;
  final VoidCallback? onBack;
  final Widget child;

  const ObScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.accent,
    required this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top bar ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: p.text, size: 20),
                  tooltip: 'Back',
                )
              else
                const SizedBox(width: 48),
              const Spacer(),
              Text(
                'Step ${step + 1} of $totalSteps',
                style: TextStyle(
                    color: p.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        // ── Progress bar ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (step + 1) / totalSteps,
              minHeight: 3,
              backgroundColor: p.border,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // ── Content ───────────────────────────────────────────────
        Expanded(child: child),
      ],
    );

    return Material(
      color: p.bg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Mobile (< 600px): full-bleed phone layout, unchanged.
            if (constraints.maxWidth < 600) return inner;
            // Web/desktop: a centred, width- and height-capped card so the
            // flow reads as a designed panel rather than a stretched phone
            // screen filling the whole viewport.
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 32),
                constraints:
                    const BoxConstraints(maxWidth: 480, maxHeight: 760),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.border),
                  boxShadow: p.cardShadow,
                ),
                child: inner,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Shared step wrapper ──────────────────────────────────────────────────────
class ObStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget content;
  final String continueLabel;
  final bool canContinue;
  final VoidCallback onContinue;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final Color accent;

  const ObStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.onContinue,
    required this.accent,
    this.continueLabel = 'Continue',
    this.canContinue = true,
    this.skipLabel,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: p.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.2)),
                const SizedBox(height: 8),
                Text(subtitle,
                    style: TextStyle(
                        color: p.sub, fontSize: 15, height: 1.4)),
                const SizedBox(height: 28),
                content,
              ],
            ),
          ),
        ),
        // ── Bottom actions ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _ObContinueButton(
                  label: continueLabel,
                  accent: accent,
                  enabled: canContinue,
                  onTap: onContinue,
                ),
              ),
              if (skipLabel != null && onSkip != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onSkip,
                  child: Text(skipLabel!,
                      style: TextStyle(
                          color: p.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ObContinueButton extends StatefulWidget {
  final String label;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;
  const _ObContinueButton({
    required this.label,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });
  @override
  State<_ObContinueButton> createState() => _ObContinueButtonState();
}

class _ObContinueButtonState extends State<_ObContinueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final alpha = widget.enabled ? 1.0 : 0.4;
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp:   widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: alpha,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              color: widget.accent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: widget.enabled
                  ? [BoxShadow(
                      color: widget.accent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1)),
          ),
        ),
      ),
    );
  }
}

// ─── Option card ──────────────────────────────────────────────────────────────
class ObOptionCard extends StatelessWidget {
  final String label;
  final String? description;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const ObOptionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.07) : p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : p.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.15)
                    : p.surface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon,
                  color: selected ? accent : p.sub, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: selected ? accent : p.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  if (description != null)
                    Text(description!,
                        style: TextStyle(
                            color: p.sub, fontSize: 12,
                            height: 1.3)),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: selected
                  ? Container(
                      key: const ValueKey('check'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 13),
                    )
                  : const SizedBox(key: ValueKey('empty'), width: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Multi-select chip ────────────────────────────────────────────────────────
class ObChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const ObChip({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : p.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? accent : p.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14,
                  color: selected ? accent : p.sub),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    color: selected ? accent : p.sub,
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

// ─── Styled text field ────────────────────────────────────────────────────────
class ObTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? label;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Color accent;
  final bool autofocus;

  const ObTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.accent,
    this.label,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!,
              style: TextStyle(
                  color: p.sub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: TextStyle(color: p.text, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: p.muted, fontSize: 16),
            filled: true,
            fillColor: p.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: p.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: p.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent, width: 2)),
          ),
        ),
      ],
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────
class ObPlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String period;
  final String description;
  final List<String> features;
  final bool recommended;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const ObPlanCard({
    super.key,
    required this.name,
    required this.price,
    required this.period,
    required this.description,
    required this.features,
    required this.accent,
    required this.onTap,
    this.recommended = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.06) : p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent
                : recommended
                    ? accent.withValues(alpha: 0.4)
                    : p.border,
            width: selected ? 2 : recommended ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: accent.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name,
                                style: TextStyle(
                                    color: p.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            if (recommended) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('BEST FIT',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(description,
                            style: TextStyle(
                                color: p.sub, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(price,
                          style: TextStyle(
                              color: accent,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      Text(period,
                          style: TextStyle(
                              color: p.muted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: accent, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f,
                              style: TextStyle(
                                  color: p.sub, fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
