import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/dashboard_providers.dart';

void showLandlordOnboardingWizard(BuildContext context) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _OnboardingWizard(),
  );
}

const _accent = Color(0xFF3B82F6);

// ─── Wizard shell ─────────────────────────────────────────────────────────────
class _OnboardingWizard extends ConsumerStatefulWidget {
  const _OnboardingWizard();

  @override
  ConsumerState<_OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends ConsumerState<_OnboardingWizard> {
  int _step = 0;
  String? _createdPropertyId;
  String? _createdAddress;

  void _nextStep({String? propertyId, String? address}) {
    setState(() {
      if (propertyId != null) _createdPropertyId = propertyId;
      if (address != null) _createdAddress = address;
      _step++;
    });
  }

  void _done() => Navigator.of(context).pop();

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _StepIndicator(step: _step, total: 3),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: switch (_step) {
                  0 => _PropertyStep(key: const ValueKey(0), onNext: _nextStep),
                  1 => _InviteStep(
                      key: const ValueKey(1),
                      propertyId: _createdPropertyId!,
                      address: _createdAddress ?? '',
                      onNext: _nextStep,
                      onSkip: _nextStep,
                    ),
                  _ => _DoneStep(key: const ValueKey(2), onDone: _done),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step indicator ───────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int step;
  final int total;
  const _StepIndicator({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final done   = i < step;
        final active = i == step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width:  active ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: done || active ? _accent : p.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Step 1: Add property ────────────────────────────────────────────────────
class _PropertyStep extends ConsumerStatefulWidget {
  final void Function({String? propertyId, String? address}) onNext;
  const _PropertyStep({super.key, required this.onNext});

  @override
  ConsumerState<_PropertyStep> createState() => _PropertyStepState();
}

class _PropertyStepState extends ConsumerState<_PropertyStep> {
  final _formKey    = GlobalKey<FormState>();
  final _line1Ctrl  = TextEditingController();
  final _postcodeCtrl = TextEditingController();

  String _type = 'house';
  int _beds = 2;
  bool _saving = false;
  String? _error;

  static const _types = ['flat', 'house', 'bungalow', 'maisonette', 'hmo', 'studio'];
  static const _typeLabels = {
    'flat': 'Flat', 'house': 'House', 'bungalow': 'Bungalow',
    'maisonette': 'Maisonette', 'hmo': 'HMO', 'studio': 'Studio',
  };

  @override
  void dispose() {
    _line1Ctrl.dispose();
    _postcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _error = null; });
    try {
      final user = supabase.auth.currentUser!;
      final postcode = _postcodeCtrl.text.trim().toUpperCase();
      final line1 = _line1Ctrl.text.trim();

      final result = await supabase.from('properties').insert({
        'landlord_id':    user.id,
        'address_line_1': line1,
        'postcode':       postcode,
        'property_type':  _type,
        'num_bedrooms':   _beds,
      }).select('id').single();

      ref.invalidate(landlordPropertiesProvider);

      widget.onNext(
        propertyId: result['id'] as String,
        address: '$line1, $postcode',
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Text('Add your first property',
            style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text('Start by adding the property address',
            style: TextStyle(color: p.sub, fontSize: 13)),
          const SizedBox(height: 20),

          _Field(
            controller: _line1Ctrl,
            label: 'Address line 1',
            hint: '12 Example Street',
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _postcodeCtrl,
            label: 'Postcode',
            hint: 'SW1A 1AA',
            caps: true,
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Property type chips
          Text('Type', style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _types.map((t) {
            final sel = t == _type;
            return GestureDetector(
              onTap: () => setState(() => _type = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _accent.withValues(alpha: 0.1) : p.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? _accent.withValues(alpha: 0.4) : p.border),
                ),
                child: Text(_typeLabels[t]!,
                  style: TextStyle(
                    color: sel ? _accent : p.sub,
                    fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),

          // Bedrooms
          Text('Bedrooms', style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            _StepperBtn(
              icon: Icons.remove_rounded,
              onTap: _beds > 0 ? () => setState(() => _beds--) : null,
              p: p,
            ),
            const SizedBox(width: 12),
            Text('$_beds', style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            _StepperBtn(
              icon: Icons.add_rounded,
              onTap: _beds < 20 ? () => setState(() => _beds++) : null,
              p: p,
            ),
          ]),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: p.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.red.withValues(alpha: 0.2))),
              child: Text(_error!, style: TextStyle(color: p.red, fontSize: 12)),
            ),
          ],

          const SizedBox(height: 24),
          _PrimaryBtn(
            label: 'Next — Invite tenant',
            loading: _saving,
            onTap: _save,
          ),
        ]),
      ),
    );
  }
}

// ─── Step 2: Invite tenant ────────────────────────────────────────────────────
class _InviteStep extends ConsumerStatefulWidget {
  final String propertyId;
  final String address;
  final void Function({String? propertyId, String? address}) onNext;
  final void Function({String? propertyId, String? address}) onSkip;
  const _InviteStep({
    super.key,
    required this.propertyId,
    required this.address,
    required this.onNext,
    required this.onSkip,
  });

  @override
  ConsumerState<_InviteStep> createState() => _InviteStepState();
}

class _InviteStepState extends ConsumerState<_InviteStep> {
  final _emailCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final user = supabase.auth.currentUser!;
      await supabase.from('tenancies').insert({
        'landlord_id':   user.id,
        'property_id':   widget.propertyId,
        'tenancy_id':    widget.propertyId,
        'invited_email': email,
        'status':        'pending',
      });
      // Send invite email — best-effort, non-fatal
      try {
        final profile = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();
        await supabase.functions.invoke('send-invitation-email', body: {
          'tenant_email':     email,
          'landlord_name':    profile['full_name'] as String? ?? 'Your landlord',
          'property_address': widget.address,
          'tenancy_id':       widget.propertyId,
        });
      } catch (_) {}
      ref.invalidate(landlordTenanciesProvider);
      if (mounted) widget.onNext();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Text('Invite a tenant',
          style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        Text(widget.address, style: TextStyle(color: p.sub, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _accent.withValues(alpha: 0.15))),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "The tenant will be invited to apply via email. You can set rent and dates once they've accepted.",
                style: TextStyle(color: _accent, fontSize: 12, height: 1.4)),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        _Field(
          controller: _emailCtrl,
          label: "Tenant's email",
          hint: 'tenant@example.com',
          keyboard: TextInputType.emailAddress,
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: p.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.red.withValues(alpha: 0.2))),
            child: Text(_error!, style: TextStyle(color: p.red, fontSize: 12)),
          ),
        ],

        const SizedBox(height: 24),
        _PrimaryBtn(label: 'Send invite', loading: _saving, onTap: _send),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => widget.onSkip(),
          child: Center(
            child: Text('Skip for now',
              style: TextStyle(color: p.sub, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ),
      ]),
    );
  }
}

// ─── Step 3: Done ─────────────────────────────────────────────────────────────
class _DoneStep extends StatelessWidget {
  final VoidCallback onDone;
  const _DoneStep({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(children: [
        const SizedBox(height: 20),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 32),
        ),
        const SizedBox(height: 20),
        Text("You're all set!",
          style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Your property has been added.\nWe\'ll notify you as soon as your tenant accepts the invite.',
          style: TextStyle(color: p.sub, fontSize: 14, height: 1.5),
          textAlign: TextAlign.center),
        const SizedBox(height: 32),
        _PrimaryBtn(label: 'Go to dashboard', onTap: onDone),
      ]),
    );
  }
}

// ─── Shared form widgets ──────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool caps;
  final TextInputType? keyboard;
  final FormFieldValidator<String>? validator;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.caps = false,
    this.keyboard,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
        textInputAction: TextInputAction.next,
        validator: validator,
        style: TextStyle(color: p.text, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.muted, fontSize: 15),
          filled: true,
          fillColor: p.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: p.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AbodePalette.of(context).red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AbodePalette.of(context).red, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _PrimaryBtn({required this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: loading ? _accent.withValues(alpha: 0.6) : _accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final AbodePalette p;
  const _StepperBtn({required this.icon, this.onTap, required this.p});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? p.card : p.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Icon(icon, size: 18, color: onTap != null ? p.text : p.border),
      ),
    );
  }
}
