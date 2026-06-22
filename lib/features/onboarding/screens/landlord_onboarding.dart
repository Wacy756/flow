import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import 'onboarding_flow.dart';

const _accent = kLandlordAccent;
const _steps  = 8;

class LandlordOnboarding extends ConsumerStatefulWidget {
  final UserProfile profile;
  final VoidCallback onComplete;
  const LandlordOnboarding({
    super.key,
    required this.profile,
    required this.onComplete,
  });

  @override
  ConsumerState<LandlordOnboarding> createState() =>
      _LandlordOnboardingState();
}

class _LandlordOnboardingState extends ConsumerState<LandlordOnboarding> {
  final _pageCtrl = PageController();
  int _step = 0;

  // ── Collected data ─────────────────────────────────────────────
  String?       _portfolioSize;   // '1' | '2-5' | '6-20' | '20+'
  String?       _managementStyle; // 'self' | 'agent' | 'want_agent'
  final _challenges = <String>{};
  // Property
  final _addr1Ctrl   = TextEditingController();
  final _postcodeCtrl= TextEditingController();
  String?       _propType;        // 'house' | 'flat' | 'hmo' | 'commercial'
  int           _bedrooms        = 1;
  // Tenant invite
  final _tenantEmailCtrl = TextEditingController();
  // Team
  bool          _hasTeam         = false;
  final List<_TeamInvite> _team  = [];
  // Plan
  String?       _selectedPlan;

  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _addr1Ctrl.dispose();
    _postcodeCtrl.dispose();
    _tenantEmailCtrl.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _step + delta;
    if (next < 0 || next >= _steps) return;
    // Skip step 6 (team invites) if no team
    if (next == 6 && !_hasTeam) {
      final skip = next + delta;
      setState(() {
        _step = skip;
        if (skip == 7 && _selectedPlan == null) _selectedPlan = _recommendedPlan;
      });
      _pageCtrl.animateToPage(
        skip,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() {
      _step = next;
      // Auto-select the recommended plan so the user can just tap Continue
      if (next == 7 && _selectedPlan == null) _selectedPlan = _recommendedPlan;
    });
    _pageCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _canContinue => switch (_step) {
    0 => _portfolioSize != null,
    1 => _managementStyle != null,
    2 => _challenges.isNotEmpty,
    3 => _addr1Ctrl.text.trim().isNotEmpty &&
        _postcodeCtrl.text.trim().isNotEmpty &&
        _propType != null,
    4 => true, // tenant invite optional
    5 => true, // team optional
    6 => true, // team invites optional
    7 => _selectedPlan != null,
    _ => false,
  };

  Future<void> _finish() async {
    if (_saving) return;
    setState(() { _saving = true; _saveError = null; });
    try {
      final userId = widget.profile.id;

      // 1. Create property — capture id for the tenancy link
      String? propertyId;
      if (_addr1Ctrl.text.trim().isNotEmpty) {
        final row = await supabase.from('properties').insert({
          'landlord_id':    userId,
          'address_line_1': _addr1Ctrl.text.trim(),
          'postcode':       _postcodeCtrl.text.trim().toUpperCase(),
          'property_type':  _propType,
          'num_bedrooms':   _bedrooms,
        }).select('id').single();
        propertyId = row['id'] as String;
      }

      // 2. Create pending tenancy if tenant email was provided
      final tenantEmail = _tenantEmailCtrl.text.trim().toLowerCase();
      if (tenantEmail.isNotEmpty && propertyId != null) {
        await supabase.from('tenancies').insert({
          'landlord_id':   userId,
          'property_id':   propertyId,
          'tenancy_id':    propertyId,
          'invited_email': tenantEmail,
          'status':        'pending',
        });
      }

      // 3. Team invites
      for (final inv in _team) {
        if (inv.email.isNotEmpty) {
          await supabase.from('profiles').upsert({
            'email':                inv.email.toLowerCase(),
            'full_name':            inv.name,
            'role':                 inv.role,
            'onboarding_completed': true,
          }, onConflict: 'email');
        }
      }

      // 4. Mark onboarding complete
      await saveOnboardingComplete(
        userId:        userId,
        plan:          _selectedPlan,
        portfolioSize: _portfolioSizeInt,
        teamSize:      _hasTeam ? 'yes' : 'none',
      );

      if (mounted) widget.onComplete();
    } catch (e) {
      setState(() {
        _saving    = false;
        _saveError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int? get _portfolioSizeInt => switch (_portfolioSize) {
    '1'    => 1,
    '2-5'  => 5,
    '6-20' => 20,
    '20+'  => 100,
    _      => null,
  };

  String get _recommendedPlan {
    switch (_portfolioSize) {
      case '1':   return 'free';
      case '20+': return 'pro';
      default:    return 'essential';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return ObScaffold(
      step: _step,
      totalSteps: _steps,
      accent: _accent,
      onBack: _step > 0 ? () => _go(-1) : null,
      child: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _step0(p),
          _step1(p),
          _step2(p),
          _step3(p),
          _step4(p),
          _step5(p),
          _step6(p),
          _step7(p),
        ],
      ),
    );
  }

  // ── Step 0: Portfolio size ─────────────────────────────────────
  Widget _step0(AbodePalette p) => ObStep(
    title: 'How many properties\ndo you own?',
    subtitle: 'We\'ll tailor everything to your portfolio size.',
    accent: _accent,
    canContinue: _canContinue,
    onContinue: () => _go(1),
    content: Column(children: [
      ObOptionCard(
        label: 'Just 1',
        description: 'Perfect for getting started',
        icon: Icons.home_rounded,
        selected: _portfolioSize == '1',
        accent: _accent,
        onTap: () => setState(() => _portfolioSize = '1'),
      ),
      ObOptionCard(
        label: '2 – 5 properties',
        description: 'Small but growing portfolio',
        icon: Icons.holiday_village_rounded,
        selected: _portfolioSize == '2-5',
        accent: _accent,
        onTap: () => setState(() => _portfolioSize = '2-5'),
      ),
      ObOptionCard(
        label: '6 – 20 properties',
        description: 'Established landlord',
        icon: Icons.apartment_rounded,
        selected: _portfolioSize == '6-20',
        accent: _accent,
        onTap: () => setState(() => _portfolioSize = '6-20'),
      ),
      ObOptionCard(
        label: '20+ properties',
        description: 'Large portfolio — unlocks the Professional pack',
        icon: Icons.location_city_rounded,
        selected: _portfolioSize == '20+',
        accent: _accent,
        onTap: () => setState(() => _portfolioSize = '20+'),
      ),
    ]),
  );

  // ── Step 1: Management style ───────────────────────────────────
  Widget _step1(AbodePalette p) => ObStep(
    title: 'How do you manage\nyour properties?',
    subtitle: 'No right answer — just helps us set up the right tools.',
    accent: _accent,
    canContinue: _canContinue,
    onContinue: () => _go(1),
    content: Column(children: [
      ObOptionCard(
        label: 'I handle everything myself',
        description: 'Full control — repairs, rent, tenants',
        icon: Icons.person_rounded,
        selected: _managementStyle == 'self',
        accent: _accent,
        onTap: () => setState(() => _managementStyle = 'self'),
      ),
      ObOptionCard(
        label: 'I work with a letting agent',
        description: 'Agent handles day-to-day management',
        icon: Icons.handshake_rounded,
        selected: _managementStyle == 'agent',
        accent: _accent,
        onTap: () => setState(() => _managementStyle = 'agent'),
      ),
      ObOptionCard(
        label: "I'm looking for an agent",
        description: 'We\'ll help you find one later',
        icon: Icons.search_rounded,
        selected: _managementStyle == 'want_agent',
        accent: _accent,
        onTap: () => setState(() => _managementStyle = 'want_agent'),
      ),
    ]),
  );

  // ── Step 2: Challenges ─────────────────────────────────────────
  Widget _step2(AbodePalette p) => ObStep(
    title: "What are your biggest\nchallenges?",
    subtitle: 'Select all that apply — we\'ll prioritise the right features.',
    accent: _accent,
    canContinue: _canContinue,
    onContinue: () => _go(1),
    content: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _challengeOptions.map((c) => ObChip(
        label: c.$1,
        icon: c.$2,
        selected: _challenges.contains(c.$1),
        accent: _accent,
        onTap: () => setState(() {
          if (_challenges.contains(c.$1)) {
            _challenges.remove(c.$1);
          } else {
            _challenges.add(c.$1);
          }
        }),
      )).toList(),
    ),
  );

  static const _challengeOptions = [
    ('Rent collection',     Icons.payments_rounded),
    ('Compliance tracking', Icons.verified_user_outlined),
    ('Maintenance',         Icons.build_rounded),
    ('Legal documents',     Icons.description_outlined),
    ('Tenant comms',        Icons.chat_bubble_outline_rounded),
    ('Financial reporting', Icons.bar_chart_rounded),
    ('Finding contractors', Icons.handyman_rounded),
    ('Deposit management',  Icons.account_balance_rounded),
  ];

  // ── Step 3: First property ─────────────────────────────────────
  Widget _step3(AbodePalette p) => ObStep(
    title: "Let's add your\nfirst property",
    subtitle: 'You can add more properties from your dashboard anytime.',
    accent: _accent,
    canContinue: _canContinue,
    onContinue: () => _go(1),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ObTextField(
          controller: _addr1Ctrl,
          hint: 'Flat 6, 4 Steward Street',
          label: 'ADDRESS',
          accent: _accent,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        ObTextField(
          controller: _postcodeCtrl,
          hint: 'E1 6FQ',
          label: 'POSTCODE',
          accent: _accent,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 20),
        Text('PROPERTY TYPE',
            style: TextStyle(
                color: p.sub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ('House',      'house',      Icons.house_rounded),
            ('Flat',       'flat',       Icons.apartment_rounded),
            ('HMO',        'hmo',        Icons.group_rounded),
            ('Commercial', 'commercial', Icons.storefront_rounded),
          ].map((t) => ObChip(
            label: t.$1,
            icon: t.$3,
            selected: _propType == t.$2,
            accent: _accent,
            onTap: () => setState(() => _propType = t.$2),
          )).toList(),
        ),
        const SizedBox(height: 20),
        Text('BEDROOMS',
            style: TextStyle(
                color: p.sub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 10),
        Row(
          children: [
            _StepperBtn(
              icon: Icons.remove_rounded,
              onTap: _bedrooms > 1
                  ? () => setState(() => _bedrooms--)
                  : null,
              accent: _accent,
            ),
            const SizedBox(width: 16),
            Text('$_bedrooms',
                style: TextStyle(
                    color: p.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 16),
            _StepperBtn(
              icon: Icons.add_rounded,
              onTap: _bedrooms < 20
                  ? () => setState(() => _bedrooms++)
                  : null,
              accent: _accent,
            ),
          ],
        ),
      ],
    ),
  );

  // ── Step 4: Invite tenant ──────────────────────────────────────
  Widget _step4(AbodePalette p) => ObStep(
    title: 'Invite your tenant',
    subtitle: 'They\'ll receive an email to set up their Abode account.',
    accent: _accent,
    canContinue: true,
    onContinue: () => _go(1),
    skipLabel: "I'll do this later",
    onSkip: () => _go(1),
    content: ObTextField(
      controller: _tenantEmailCtrl,
      hint: 'tenant@email.com',
      label: 'TENANT EMAIL',
      accent: _accent,
      keyboardType: TextInputType.emailAddress,
      textCapitalization: TextCapitalization.none,
    ),
  );

  // ── Step 5: Have team? ─────────────────────────────────────────
  Widget _step5(AbodePalette p) => ObStep(
    title: 'Do you manage alone?',
    subtitle: 'Some landlords have a partner or assistant who helps out.',
    accent: _accent,
    canContinue: true,
    onContinue: () => _go(1),
    content: Column(children: [
      ObOptionCard(
        label: 'Just me',
        description: 'Solo landlord — all access to you',
        icon: Icons.person_rounded,
        selected: !_hasTeam,
        accent: _accent,
        onTap: () => setState(() => _hasTeam = false),
      ),
      ObOptionCard(
        label: 'I have someone who helps',
        description: 'Invite a partner, PA or property manager',
        icon: Icons.group_rounded,
        selected: _hasTeam,
        accent: _accent,
        onTap: () {
          setState(() {
            _hasTeam = true;
            if (_team.isEmpty) _team.add(_TeamInvite());
          });
        },
      ),
    ]),
  );

  // ── Step 6: Team invites ───────────────────────────────────────
  Widget _step6(AbodePalette p) => ObStep(
    title: 'Invite your team',
    subtitle: 'They\'ll get an email to join your Abode workspace.',
    accent: _accent,
    canContinue: true,
    onContinue: () => _go(1),
    skipLabel: 'Skip for now',
    onSkip: () => _go(1),
    content: Column(
      children: [
        ..._team.asMap().entries.map((e) => _TeamRow(
          invite: e.value,
          accent: _accent,
          onChanged: () => setState(() {}),
        )),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _team.add(_TeamInvite())),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  color: _accent, size: 18),
              const SizedBox(width: 6),
              Text('Add another',
                  style: TextStyle(
                      color: _accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Step 7: Plan ───────────────────────────────────────────────
  Widget _step7(AbodePalette p) => ObStep(
    title: 'Your recommended plan',
    subtitle: 'Based on your portfolio — change or cancel anytime.',
    accent: _accent,
    canContinue: _selectedPlan != null && !_saving,
    continueLabel: _saving ? 'Setting up…' : 'Get started',
    onContinue: _finish,
    content: Column(children: [
      if (_saveError != null) ...[
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
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
      ObPlanCard(
        name: 'Starter',
        price: '£0',
        period: 'forever',
        description: 'Your first property — free, forever',
        features: const [
          '1 property, free',
          'Tenant & tenancy management',
          'Maintenance & incidents',
          'Rent tracking · messaging',
        ],
        recommended: _recommendedPlan == 'free',
        selected: _selectedPlan == 'free',
        accent: _accent,
        onTap: () => setState(() => _selectedPlan = 'free'),
      ),
      ObPlanCard(
        name: 'Abode',
        price: 'From £3.50',
        period: '/ property · mo',
        description: 'Per property — first one free, every feature included',
        features: const [
          'Unlimited properties (billed per property)',
          'First property always free',
          'Contractor marketplace',
          'Full compliance & document vault',
          'Rent ledger, legal notices & analytics',
          '1 team seat included (+£8/seat)',
        ],
        recommended: _recommendedPlan == 'essential',
        selected: _selectedPlan == 'essential',
        accent: _accent,
        onTap: () => setState(() => _selectedPlan = 'essential'),
      ),
      ObPlanCard(
        name: 'Professional',
        price: 'From £3.50',
        period: '/ property · mo',
        description: 'For agencies & 20+ portfolios',
        features: const [
          'Everything in Abode',
          'White-label & branding',
          'API access',
          'Priority support (same-day)',
          'Auto-included at 20+ properties',
        ],
        recommended: _recommendedPlan == 'pro',
        selected: _selectedPlan == 'pro',
        accent: _accent,
        onTap: () => setState(() => _selectedPlan = 'pro'),
      ),
    ]),
  );
}

// ─── Stepper button ───────────────────────────────────────────────────────────
class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  const _StepperBtn({required this.icon, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onTap != null
              ? accent.withValues(alpha: 0.1)
              : p.border,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: onTap != null ? accent : p.border),
        ),
        child: Icon(icon,
            color: onTap != null ? accent : p.muted, size: 20),
      ),
    );
  }
}

// ─── Team invite row ──────────────────────────────────────────────────────────
class _TeamInvite {
  String name = '';
  String email = '';
  String role = 'viewer';
}

class _TeamRow extends StatefulWidget {
  final _TeamInvite invite;
  final Color accent;
  final VoidCallback onChanged;
  const _TeamRow({
    required this.invite,
    required this.accent,
    required this.onChanged,
  });
  @override
  State<_TeamRow> createState() => _TeamRowState();
}

class _TeamRowState extends State<_TeamRow> {
  late final _nameCtrl  = TextEditingController(text: widget.invite.name);
  late final _emailCtrl = TextEditingController(text: widget.invite.email);

  static const _roles = [
    ('Admin',    'admin'),
    ('Manager',  'manager'),
    ('Viewer',   'viewer'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: p.text, fontSize: 14),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) { widget.invite.name = v; widget.onChanged(); },
            decoration: InputDecoration(
              hintText: 'Their name',
              hintStyle: TextStyle(color: p.muted, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          Divider(color: p.border, height: 16),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: p.text, fontSize: 14),
            onChanged: (v) { widget.invite.email = v; widget.onChanged(); },
            decoration: InputDecoration(
              hintText: 'their@email.com',
              hintStyle: TextStyle(color: p.muted, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          Divider(color: p.border, height: 16),
          Row(
            children: _roles.map((r) {
              final sel = widget.invite.role == r.$2;
              return GestureDetector(
                onTap: () => setState(() {
                  widget.invite.role = r.$2;
                  widget.onChanged();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel
                        ? widget.accent.withValues(alpha: 0.12)
                        : p.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? widget.accent : p.border),
                  ),
                  child: Text(r.$1,
                      style: TextStyle(
                          color: sel ? widget.accent : p.sub,
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.w400)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
