import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import 'onboarding_flow.dart';

const _accent = Color(0xFF22C55E); // green — tenant brand colour
const _steps  = 2;

class TenantOnboarding extends ConsumerStatefulWidget {
  final UserProfile profile;
  final VoidCallback onComplete;
  const TenantOnboarding({
    super.key,
    required this.profile,
    required this.onComplete,
  });

  @override
  ConsumerState<TenantOnboarding> createState() => _TenantOnboardingState();
}

class _TenantOnboardingState extends ConsumerState<TenantOnboarding> {
  final _pageCtrl  = PageController();
  int  _step       = 0;

  late final _nameCtrl  = TextEditingController(text: widget.profile.fullName == 'User' ? '' : widget.profile.fullName);
  late final _phoneCtrl = TextEditingController(text: widget.profile.phone ?? '');

  bool    _saving    = false;
  String? _saveError;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    0 => _nameCtrl.text.trim().length >= 2,
    _ => true,
  };

  void _go(int delta) {
    final next = _step + delta;
    if (next < 0 || next >= _steps) return;
    setState(() => _step = next);
    _pageCtrl.animateToPage(next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() { _saving = true; _saveError = null; });
    try {
      await supabase.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty)
          'phone': _phoneCtrl.text.trim(),
      }).eq('id', widget.profile.id);

      await saveOnboardingComplete(
        userId: widget.profile.id,
        plan:   null,
      );

      if (mounted) widget.onComplete();
    } catch (e) {
      setState(() {
        _saving    = false;
        _saveError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => ObScaffold(
    step:       _step,
    totalSteps: _steps,
    accent:     _accent,
    onBack:     _step > 0 ? () => _go(-1) : null,
    child: PageView(
      controller: _pageCtrl,
      physics: const NeverScrollableScrollPhysics(),
      children: [_step0(), _step1()],
    ),
  );

  // ── Step 0: Name + phone ───────────────────────────────────────
  Widget _step0() => ObStep(
    title: 'Welcome to Abode',
    subtitle: 'Quick intro — takes less than a minute.',
    accent: _accent,
    canContinue: _canContinue,
    onContinue: () => _go(1),
    content: AnimatedBuilder(
      animation: _nameCtrl,
      builder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ObTextField(
            controller: _nameCtrl,
            hint: 'Your full name',
            label: 'YOUR NAME',
            accent: _accent,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          ObTextField(
            controller: _phoneCtrl,
            hint: '+44 7700 900 000',
            label: 'PHONE (OPTIONAL)',
            accent: _accent,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          _InfoBox(
            icon: Icons.info_outline_rounded,
            text: 'Your landlord can contact you via the app — we never share your number with third parties.',
            accent: _accent,
          ),
        ],
      ),
    ),
  );

  // ── Step 1: Done ───────────────────────────────────────────────
  Widget _step1() {
    final p = AbodePalette.of(context);
    return ObStep(
      title: "You're all set",
      subtitle: 'Your tenancy invite will appear on your dashboard.',
      accent: _accent,
      canContinue: !_saving,
      continueLabel: _saving ? 'Setting up…' : 'Go to dashboard',
      onContinue: _finish,
      content: Column(
        children: [
          const SizedBox(height: 8),
          _FeatureRow(icon: Icons.home_outlined, label: 'See your tenancy and rent details', accent: _accent),
          _FeatureRow(icon: Icons.build_outlined, label: 'Log maintenance requests instantly', accent: _accent),
          _FeatureRow(icon: Icons.description_outlined, label: 'Access your documents anytime', accent: _accent),
          _FeatureRow(icon: Icons.chat_bubble_outline_rounded, label: 'Message your landlord directly', accent: _accent),
          const SizedBox(height: 20),
          if (_saveError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.red.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: p.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_saveError!,
                  style: TextStyle(color: p.red, fontSize: 13, height: 1.4))),
              ]),
            ),
        ],
      ),
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  const _FeatureRow({required this.icon, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
          style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;
  const _InfoBox({required this.icon, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: accent, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: TextStyle(color: p.sub, fontSize: 12, height: 1.5))),
      ]),
    );
  }
}
