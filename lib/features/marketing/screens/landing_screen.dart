import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Colour palette
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const Color bg     = Color(0xFF0A0A0C);
  static const Color card   = Color(0xFF131316);
  static const Color border = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
  static const Color text   = Color(0xFFF2F2F3);
  static const Color muted  = Color(0xFF6B6B72);
  static const Color green  = Color(0xFF4ADE80);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Typography helpers (Geist)
// ─────────────────────────────────────────────────────────────────────────────

TextStyle _geist({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _C.text,
  double? letterSpacing,
  double? height,
  FontStyle? fontStyle,
}) {
  return GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Role styling
// ─────────────────────────────────────────────────────────────────────────────

class _RoleStyle {
  final Color bg;
  final Color border;
  final Color accent;
  final Color label;
  const _RoleStyle({
    required this.bg,
    required this.border,
    required this.accent,
    required this.label,
  });
}

const _roleStyles = <String, _RoleStyle>{
  'landlord': _RoleStyle(
    bg:     Color(0xFF0F2D1F),
    border: Color(0x334ADE80), // rgba(74,222,128,0.2)
    accent: Color(0xFF4ADE80),
    label:  Color(0xB34ADE80), // rgba(74,222,128,0.7)
  ),
  'tenant': _RoleStyle(
    bg:     Color(0xFF1A1A0A),
    border: Color(0x33EAB308),
    accent: Color(0xFFEAB308),
    label:  Color(0xB3EAB308),
  ),
  'contractor': _RoleStyle(
    bg:     Color(0xFF1F0F0A),
    border: Color(0x33FB923C),
    accent: Color(0xFFFB923C),
    label:  Color(0xB3FB923C),
  ),
  'agent': _RoleStyle(
    bg:     Color(0xFF0D0F2A),
    border: Color(0x33818CF8),
    accent: Color(0xFF818CF8),
    label:  Color(0xB3818CF8),
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
//  Logo — green rounded square with dark wave glyph
// ─────────────────────────────────────────────────────────────────────────────

class _FlowLogo extends StatelessWidget {
  final double size;
  const _FlowLogo({this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _C.green,
        borderRadius: BorderRadius.circular(size * 0.30),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.5, size * 0.5),
          painter: _FlowWavePainter(),
        ),
      ),
    );
  }
}

class _FlowWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final f = s / 16.0;

    final stroke = Paint()
      ..color = _C.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * f
      ..strokeCap = StrokeCap.round;

    final p1 = Path()
      ..moveTo(2 * f, 8 * f)
      ..cubicTo(2 * f, 8 * f, 4 * f, 5 * f, 8 * f, 5 * f)
      ..cubicTo(12 * f, 5 * f, 14 * f, 8 * f, 14 * f, 8 * f);
    canvas.drawPath(p1, stroke);

    final dim = Paint()
      ..color = _C.bg.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * f
      ..strokeCap = StrokeCap.round;
    final p2 = Path()
      ..moveTo(2 * f, 11 * f)
      ..cubicTo(2 * f, 11 * f, 4 * f, 8 * f, 8 * f, 8 * f)
      ..cubicTo(12 * f, 8 * f, 14 * f, 11 * f, 14 * f, 11 * f);
    canvas.drawPath(p2, dim);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Role icons — 24-unit viewBox, scalable
// ─────────────────────────────────────────────────────────────────────────────

abstract class _StrokeIconPainter extends CustomPainter {
  final Color color;
  _StrokeIconPainter(this.color);

  Paint _stroke(double f) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1 * f
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is _StrokeIconPainter && oldDelegate.color != color;
}

class _LandlordIconPainter extends _StrokeIconPainter {
  _LandlordIconPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 24.0;
    final p = _stroke(f);

    // Roof
    final roof = Path()
      ..moveTo(3 * f, 11 * f)
      ..lineTo(12 * f, 3 * f)
      ..lineTo(21 * f, 11 * f);
    canvas.drawPath(roof, p);

    // Body with door cutout
    final body = Path()
      ..moveTo(5 * f, 9.2 * f)
      ..lineTo(5 * f, 20 * f)
      ..lineTo(10 * f, 20 * f)
      ..lineTo(10 * f, 14 * f)
      ..lineTo(14 * f, 14 * f)
      ..lineTo(14 * f, 20 * f)
      ..lineTo(19 * f, 20 * f)
      ..lineTo(19 * f, 9.2 * f);
    canvas.drawPath(body, p);
  }
}

class _TenantIconPainter extends _StrokeIconPainter {
  _TenantIconPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 24.0;
    final p = _stroke(f);

    // Head
    canvas.drawCircle(Offset(12 * f, 8 * f), 4 * f, p);

    // Body — curved shoulders
    final body = Path()
      ..moveTo(4 * f, 21 * f)
      ..cubicTo(4 * f, 16 * f, 7 * f, 14 * f, 12 * f, 14 * f)
      ..cubicTo(17 * f, 14 * f, 20 * f, 16 * f, 20 * f, 21 * f);
    canvas.drawPath(body, p);
  }
}

class _ContractorIconPainter extends _StrokeIconPainter {
  _ContractorIconPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 24.0;
    final p = _stroke(f);

    // Diagonal wrench: open jaw at top-right, handle to bottom-left
    final wrench = Path()
      ..moveTo(14.7 * f, 3 * f)
      ..cubicTo(14.7 * f, 3 * f, 18 * f, 3 * f, 18 * f, 6.3 * f)
      ..cubicTo(18 * f, 9.6 * f, 14.7 * f, 11.5 * f, 14.7 * f, 11.5 * f)
      ..lineTo(8 * f, 18.2 * f)
      ..cubicTo(6.9 * f, 19.3 * f, 4.7 * f, 19.3 * f, 3.6 * f, 18.2 * f)
      ..cubicTo(2.5 * f, 17.1 * f, 2.5 * f, 14.9 * f, 3.6 * f, 13.8 * f)
      ..lineTo(10.3 * f, 7.1 * f);
    canvas.drawPath(wrench, p);
  }
}

class _AgentIconPainter extends _StrokeIconPainter {
  _AgentIconPainter(super.color);

  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 24.0;
    final p = _stroke(f);

    // Body
    canvas.drawRRect(
      RRect.fromLTRBR(
        4 * f, 11 * f, 20 * f, 21 * f,
        Radius.circular(2 * f),
      ),
      p,
    );

    // Arch
    final arch = Path()
      ..moveTo(8 * f, 11 * f)
      ..lineTo(8 * f, 7 * f)
      ..cubicTo(8 * f, 4.79 * f, 9.79 * f, 3 * f, 12 * f, 3 * f)
      ..cubicTo(14.21 * f, 3 * f, 16 * f, 4.79 * f, 16 * f, 7 * f)
      ..lineTo(16 * f, 11 * f);
    canvas.drawPath(arch, p);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reusable: radial glow positioned inside a Stack
// ─────────────────────────────────────────────────────────────────────────────

class _RadialGlow extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _RadialGlow({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.5,
              colors: [color, Colors.transparent],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pressed-state wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp:   (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: _down ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Root screen
// ─────────────────────────────────────────────────────────────────────────────

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _NavBar(),
              _Hero(),
              _RolesSection(),
              _HowItWorks(),
              _FooterCta(),
              _BottomBar(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Nav bar
// ─────────────────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const _FlowLogo(size: 30),
              const SizedBox(width: 10),
              Text(
                'Flow',
                style: _geist(
                  size: 17,
                  weight: FontWeight.w600,
                  letterSpacing: -0.51,
                ),
              ),
            ],
          ),
          _Pressable(
            onTap: () => context.go(AppRoutes.auth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: _C.border),
              ),
              child: Text(
                'Sign in',
                style: _geist(
                  size: 14,
                  weight: FontWeight.w400,
                  color: _C.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hero
// ─────────────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 36, 22, 44),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Glow behind headline
          Positioned(
            top: -20,
            child: _RadialGlow(
              width: 260,
              height: 200,
              color: _C.green.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pill badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _C.green.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _C.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Property management, simplified',
                      style: _geist(
                        size: 12,
                        weight: FontWeight.w400,
                        color: _C.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Headline
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: _geist(
                    size: 38,
                    weight: FontWeight.w600,
                    letterSpacing: -1.9,
                    height: 1.06,
                  ),
                  children: [
                    const TextSpan(text: 'Stop chasing.\n'),
                    TextSpan(
                      text: 'Start flowing.',
                      style: _geist(
                        size: 38,
                        weight: FontWeight.w600,
                        color: _C.green,
                        letterSpacing: -1.9,
                        height: 1.06,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'One app for landlords, tenants, contractors, and agents.',
                textAlign: TextAlign.center,
                style: _geist(
                  size: 15,
                  weight: FontWeight.w300,
                  color: _C.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              // CTA
              _Pressable(
                onTap: () => context.go(AppRoutes.auth),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    color: _C.green,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: Text(
                      'Get started free',
                      style: _geist(
                        size: 16,
                        weight: FontWeight.w500,
                        color: _C.bg,
                        letterSpacing: -0.32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Sign-in link
              _Pressable(
                onTap: () => context.go(AppRoutes.auth),
                child: RichText(
                  text: TextSpan(
                    style: _geist(size: 14, color: _C.muted),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
                        style: _geist(size: 14, color: _C.text),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Roles section
// ─────────────────────────────────────────────────────────────────────────────

class _RoleData {
  final String id;
  final String label;
  final CustomPainter Function(Color) iconBuilder;
  const _RoleData({
    required this.id,
    required this.label,
    required this.iconBuilder,
  });
}

final List<_RoleData> _roles = [
  _RoleData(
    id: 'landlord',
    label: 'Landlord',
    iconBuilder: (c) => _LandlordIconPainter(c),
  ),
  _RoleData(
    id: 'tenant',
    label: 'Tenant',
    iconBuilder: (c) => _TenantIconPainter(c),
  ),
  _RoleData(
    id: 'contractor',
    label: 'Contractor',
    iconBuilder: (c) => _ContractorIconPainter(c),
  ),
  _RoleData(
    id: 'agent',
    label: 'Agent',
    iconBuilder: (c) => _AgentIconPainter(c),
  ),
];

class _RolesSection extends StatelessWidget {
  const _RolesSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "WHO IT'S FOR",
            style: _geist(
              size: 11,
              weight: FontWeight.w500,
              color: _C.muted,
              letterSpacing: 0.88,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Built for\neveryone.',
            textAlign: TextAlign.center,
            style: _geist(
              size: 26,
              weight: FontWeight.w600,
              letterSpacing: -1.04,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
            children: _roles.map((r) => _RoleCard(data: r)).toList(),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final _RoleData data;
  const _RoleCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final s = _roleStyles[data.id]!;

    return _Pressable(
      onTap: () => context.go(AppRoutes.auth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: s.bg,
            border: Border.all(color: s.border),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              // Glow at bottom-centre, offset -20px below card bottom
              Positioned(
                bottom: -20,
                left: 0,
                right: 0,
                child: Center(
                  child: _RadialGlow(
                    width: 140,
                    height: 140,
                    color: s.accent.withValues(alpha: 0.20),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(72, 72),
                      painter: data.iconBuilder(s.accent),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.label,
                      style: _geist(
                        size: 13,
                        weight: FontWeight.w400,
                        color: s.label,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  How it works
// ─────────────────────────────────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    ('1', 'Create your account', 'Pick your role, verify your email.'),
    ('2', 'Add your property', 'Invite tenants directly by email.'),
    ('3', 'Everything flows', 'Incidents, quotes, documents — one thread.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'HOW IT WORKS',
            style: _geist(
              size: 11,
              weight: FontWeight.w500,
              color: _C.muted,
              letterSpacing: 0.88,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Up in a\nminute.',
            textAlign: TextAlign.center,
            style: _geist(
              size: 26,
              weight: FontWeight.w600,
              letterSpacing: -1.04,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 20),
          ..._steps.asMap().entries.map((e) {
            final isLast = e.key == _steps.length - 1;
            final step = e.value;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: _StepCard(
                number: step.$1,
                title: step.$2,
                body: step.$3,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _C.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: _C.green.withValues(alpha: 0.20),
              ),
            ),
            child: Center(
              child: Text(
                number,
                style: _geist(
                  size: 13,
                  weight: FontWeight.w500,
                  color: _C.green,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _geist(
                    size: 15,
                    weight: FontWeight.w500,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: _geist(
                    size: 13,
                    weight: FontWeight.w300,
                    color: _C.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Footer CTA card
// ─────────────────────────────────────────────────────────────────────────────

class _FooterCta extends StatelessWidget {
  const _FooterCta();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _C.border),
          ),
          child: Stack(
            children: [
              // Glow at the bottom
              Positioned(
                bottom: -40,
                left: 0,
                right: 0,
                child: Center(
                  child: _RadialGlow(
                    width: 220,
                    height: 180,
                    color: _C.green.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: _geist(
                          size: 30,
                          weight: FontWeight.w600,
                          letterSpacing: -1.2,
                          height: 1.1,
                        ),
                        children: [
                          const TextSpan(text: 'Stop chasing.\n'),
                          TextSpan(
                            text: 'Start flowing.',
                            style: _geist(
                              size: 30,
                              weight: FontWeight.w600,
                              color: _C.green,
                              letterSpacing: -1.2,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Free for tenants. Fair for everyone else.',
                      textAlign: TextAlign.center,
                      style: _geist(
                        size: 13,
                        weight: FontWeight.w300,
                        color: _C.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _Pressable(
                      onTap: () => context.go(AppRoutes.auth),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        decoration: BoxDecoration(
                          color: _C.green,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: Text(
                            'Get started free',
                            style: _geist(
                              size: 16,
                              weight: FontWeight.w500,
                              color: _C.bg,
                              letterSpacing: -0.32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Pressable(
                      onTap: () => context.go(AppRoutes.auth),
                      child: RichText(
                        text: TextSpan(
                          style: _geist(size: 13, color: _C.muted),
                          children: [
                            const TextSpan(text: 'Have an account? '),
                            TextSpan(
                              text: 'Sign in',
                              style: _geist(size: 13, color: _C.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom footer bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 16, 22, 28 + bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Flow',
            style: _geist(
              size: 13,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.20),
              letterSpacing: -0.26,
            ),
          ),
          Row(
            children: [
              _FooterLink('Privacy', onTap: () {}),
              const SizedBox(width: 16),
              _FooterLink('Terms', onTap: () {}),
              const SizedBox(width: 16),
              _FooterLink('Contact', onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Text(
        label,
        style: _geist(size: 12, color: _C.muted),
      ),
    );
  }
}
