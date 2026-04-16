import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Brand colours
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const Color bgPage       = Color(0xFFF5F2EE);
  static const Color bgSurface    = Color(0xFFFDFAF7);
  static const Color border       = Color(0xFFE0DAD2);
  static const Color textPrimary  = Color(0xFF1C1C1A);
  static const Color textSecondary= Color(0xFF7A6E62);
  static const Color textMuted    = Color(0xFFA89E93);
  static const Color green        = Color(0xFF2D6A2D);
  static const Color greenLight   = Color(0xFF6ECF6E);
  static const Color greenBg      = Color(0xFFD6EDD6);
  static const Color darkBg       = Color(0xFF141E14);
  static const Color darkBorder   = Color(0xFF1F2E1F);
  static const Color darkMuted    = Color(0xFF4A5E4A);
  static const Color darkSubtle   = Color(0xFF3D4E3D);
}

class _RoleColors {
  final Color bg;
  final Color glow;
  const _RoleColors(this.bg, this.glow);
}

const _roleColors = {
  'landlord':   _RoleColors(Color(0xFF1E3A5F), Color(0xFF60A5FA)),
  'tenant':     _RoleColors(Color(0xFF1A3D1A), Color(0xFF6ECF6E)),
  'contractor': _RoleColors(Color(0xFF7C2D00), Color(0xFFFB923C)),
  'agent':      _RoleColors(Color(0xFF1C1C1A), Color(0xFFA78BFA)),
};

// ─────────────────────────────────────────────────────────────────────────────
//  Flow logo — CustomPaint, reusable
// ─────────────────────────────────────────────────────────────────────────────

class _FlowLogo extends StatelessWidget {
  final double size;
  const _FlowLogo({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _FlowLogoPainter());
  }
}

class _FlowLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = s * 0.27;

    // Background rounded rect
    final bgPaint = Paint()..color = _C.green;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
      bgPaint,
    );

    // Scale factor from viewBox 48 to actual size
    final f = s / 48.0;

    // Wave 1 — full opacity
    final w1 = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.052
      ..strokeCap = StrokeCap.round;
    final p1 = Path()
      ..moveTo(14 * f, 26 * f)
      ..cubicTo(14 * f, 26 * f, 17 * f, 20 * f, 24 * f, 20 * f)
      ..cubicTo(31 * f, 20 * f, 34 * f, 26 * f, 34 * f, 26 * f);
    canvas.drawPath(p1, w1);

    // Wave 2 — 50% opacity
    final w2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.052
      ..strokeCap = StrokeCap.round;
    final p2 = Path()
      ..moveTo(14 * f, 32 * f)
      ..cubicTo(14 * f, 32 * f, 17 * f, 26 * f, 24 * f, 26 * f)
      ..cubicTo(31 * f, 26 * f, 34 * f, 32 * f, 34 * f, 32 * f);
    canvas.drawPath(p2, w2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SVG icon painters
// ─────────────────────────────────────────────────────────────────────────────

class _LandlordIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 18.0;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * f
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Roof
    final roof = Path()
      ..moveTo(2 * f, 9 * f)
      ..lineTo(9 * f, 2.5 * f)
      ..lineTo(16 * f, 9 * f);
    canvas.drawPath(roof, p);

    // House body
    final body = Path()
      ..moveTo(4 * f, 7.5 * f)
      ..lineTo(4 * f, 15 * f)
      ..cubicTo(4 * f, 15.55 * f, 4.45 * f, 16 * f, 5 * f, 16 * f)
      ..lineTo(8 * f, 16 * f)
      ..lineTo(8 * f, 13 * f)
      ..lineTo(10 * f, 13 * f)
      ..lineTo(10 * f, 16 * f)
      ..lineTo(13 * f, 16 * f)
      ..cubicTo(13.55 * f, 16 * f, 14 * f, 15.55 * f, 14 * f, 15 * f)
      ..lineTo(14 * f, 7.5 * f);
    canvas.drawPath(body, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TenantIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 18.0;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * f
      ..strokeCap = StrokeCap.round;

    // Head
    canvas.drawCircle(Offset(9 * f, 6 * f), 3 * f, p);

    // Body
    final body = Path()
      ..moveTo(3 * f, 16 * f)
      ..cubicTo(3 * f, 12.686 * f, 5.686 * f, 11 * f, 9 * f, 11 * f)
      ..cubicTo(12.314 * f, 11 * f, 15 * f, 12.686 * f, 15 * f, 16 * f);
    canvas.drawPath(body, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ContractorIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 18.0;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * f
      ..strokeCap = StrokeCap.round;

    // Wrench handle
    final wrench = Path()
      ..moveTo(10.5 * f, 3 * f)
      ..cubicTo(10.5 * f, 3 * f, 12.607 * f, 3 * f, 12.607 * f, 5.107 * f)
      ..cubicTo(12.607 * f, 7.214 * f, 10.5 * f, 8.657 * f, 10.5 * f, 8.657 * f)
      ..lineTo(5.657 * f, 13.5 * f)
      ..cubicTo(4.876 * f, 14.281 * f, 3.281 * f, 14.281 * f, 2.5 * f, 13.5 * f)
      ..cubicTo(1.719 * f, 12.719 * f, 1.719 * f, 11.124 * f, 2.5 * f, 10.343 * f)
      ..lineTo(7.343 * f, 5.5 * f);
    canvas.drawPath(wrench, p);

    // Bolt circle
    canvas.drawCircle(Offset(13.5 * f, 4.5 * f), 1.5 * f, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AgentIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 18.0;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * f
      ..strokeCap = StrokeCap.round;

    // Briefcase body
    canvas.drawRRect(
      RRect.fromLTRBR(3 * f, 7 * f, 15 * f, 15 * f, Radius.circular(1.5 * f)),
      stroke,
    );

    // Handle
    final handle = Path()
      ..moveTo(6 * f, 7 * f)
      ..lineTo(6 * f, 5.5 * f)
      ..cubicTo(6 * f, 3.843 * f, 7.343 * f, 2.5 * f, 9 * f, 2.5 * f)
      ..cubicTo(10.657 * f, 2.5 * f, 12 * f, 3.843 * f, 12 * f, 5.5 * f)
      ..lineTo(12 * f, 7 * f);
    canvas.drawPath(handle, stroke);

    // Lock dot
    final fill = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(9 * f, 11 * f), 1.2 * f, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 10.0;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * f
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(3 * f, 7 * f)
      ..lineTo(7 * f, 3 * f)
      ..moveTo(7 * f, 3 * f)
      ..lineTo(4 * f, 3 * f)
      ..moveTo(7 * f, 3 * f)
      ..lineTo(7 * f, 6 * f);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final f = size.width / 10.0;
    final p = Paint()..color = _C.green;
    final path = Path()
      ..moveTo(5 * f, 1 * f)
      ..lineTo(6.2 * f, 3.6 * f)
      ..lineTo(9 * f, 4.1 * f)
      ..lineTo(7 * f, 6 * f)
      ..lineTo(7.5 * f, 8.9 * f)
      ..lineTo(5 * f, 7.6 * f)
      ..lineTo(2.5 * f, 8.9 * f)
      ..lineTo(3 * f, 6 * f)
      ..lineTo(1 * f, 4.1 * f)
      ..lineTo(3.8 * f, 3.6 * f)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Root screen
// ─────────────────────────────────────────────────────────────────────────────

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgPage,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _NavBar(),
            _Hero(),
            _StatsStrip(),
            _RolesSection(),
            _HowItWorks(),
            _Testimonial(),
            _BottomCta(),
            _Footer(),
          ],
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
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 8, 20, 8),
      decoration: const BoxDecoration(
        color: _C.bgPage,
        border: Border(bottom: BorderSide(color: _C.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const _FlowLogo(size: 28),
              const SizedBox(width: 8),
              const Text(
                'Flow',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => context.go(AppRoutes.auth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC8C0B5)),
              ),
              child: const Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _C.textPrimary,
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
    return Container(
      color: _C.bgPage,
      padding: const EdgeInsets.fromLTRB(20, 38, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pill badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _C.greenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _C.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Property management, simplified',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _C.green,
                    letterSpacing: 0.02,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Headline
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
                height: 1.1,
                letterSpacing: -1.2,
              ),
              children: [
                TextSpan(text: 'Stop chasing.\n'),
                TextSpan(
                  text: 'Start flowing.',
                  style: TextStyle(color: _C.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Subtitle
          const Text(
            'Free for tenants. Simple pricing for landlords and agents. Contractors keep 95% of every job.',
            style: TextStyle(
              fontSize: 13,
              color: _C.textSecondary,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 28),

          // CTA button
          GestureDetector(
            onTap: () => context.go(AppRoutes.auth),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _C.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Get started',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sign in link
          Center(
            child: GestureDetector(
              onTap: () => context.go(AppRoutes.auth),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 11),
                  children: [
                    TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: _C.textMuted),
                    ),
                    TextSpan(
                      text: 'Sign in',
                      style: TextStyle(
                        color: _C.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
//  Stats strip
// ─────────────────────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  static const _stats = [
    ('2.4k', 'Properties'),
    ('98%', 'Issues resolved'),
    ('4.9', 'App rating'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.bgSurface,
        border: Border(
          top: BorderSide(color: _C.border, width: 0.5),
          bottom: BorderSide(color: _C.border, width: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: List.generate(_stats.length * 2 - 1, (i) {
            if (i.isOdd) {
              return Container(width: 0.5, color: _C.border);
            }
            final s = _stats[i ~/ 2];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.$1,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _C.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      s.$2,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Role cards section
// ─────────────────────────────────────────────────────────────────────────────

class _RoleData {
  final String id;
  final String label;
  final String desc;
  final String badge;
  final String badgeType; // 'free', 'paid', 'cut'
  final CustomPainter Function() iconPainter;
  const _RoleData({
    required this.id,
    required this.label,
    required this.desc,
    required this.badge,
    required this.badgeType,
    required this.iconPainter,
  });
}

final _roles = [
  _RoleData(
    id: 'landlord',
    label: 'Landlord',
    desc: 'Manage your properties and tenants from one place',
    badge: 'Subscription',
    badgeType: 'paid',
    iconPainter: () => _LandlordIconPainter(),
  ),
  _RoleData(
    id: 'tenant',
    label: 'Tenant',
    desc: 'Report issues and track repairs in real time',
    badge: 'Free forever',
    badgeType: 'free',
    iconPainter: () => _TenantIconPainter(),
  ),
  _RoleData(
    id: 'contractor',
    label: 'Contractor',
    desc: 'Receive jobs and quotes. Keep 95% of every job',
    badge: '5% per job',
    badgeType: 'cut',
    iconPainter: () => _ContractorIconPainter(),
  ),
  _RoleData(
    id: 'agent',
    label: 'Agent',
    desc: 'Run your full portfolio. Add landlords and manage everything',
    badge: 'Subscription',
    badgeType: 'paid',
    iconPainter: () => _AgentIconPainter(),
  ),
];

class _RolesSection extends StatelessWidget {
  const _RolesSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bgPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'WHO IS IT FOR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Built for\neveryone involved',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          // Grid
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
              children: _roles.map((r) => _RoleCard(data: r)).toList(),
            ),
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
    final colors = _roleColors[data.id]!;
    final isAgent = data.id == 'agent';

    Color badgeBg;
    Color badgeText;
    switch (data.badgeType) {
      case 'free':
        badgeBg = const Color(0xFF6ECF6E).withValues(alpha: 0.2);
        badgeText = _C.greenLight;
        break;
      case 'cut':
        badgeBg = const Color(0xFFFB923C).withValues(alpha: 0.25);
        badgeText = const Color(0xFFFB923C);
        break;
      default:
        badgeBg = Colors.white.withValues(alpha: 0.1);
        badgeText = Colors.white.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onTap: () => context.go(AppRoutes.auth),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Glow
            Positioned(
              bottom: -18,
              right: -18,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: colors.glow.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon wrap
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: isAgent ? 0.08 : 0.13),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(18, 18),
                        painter: data.iconPainter(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.desc,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      data.badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: badgeText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Positioned(
              bottom: 14,
              right: 14,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(10, 10),
                    painter: _ArrowPainter(),
                  ),
                ),
              ),
            ),
          ],
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
    ('1', 'Create your account', 'Pick your role, verify your email \u2014 takes under a minute.'),
    ('2', 'Add your property', 'Landlords add tenancies and invite tenants directly by email.'),
    ('3', 'Everything flows', 'Incidents, quotes, documents \u2014 all in one thread, in real time.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.bgSurface,
        border: Border(top: BorderSide(color: _C.border, width: 0.5)),
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOW IT WORKS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _C.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              // Connector
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Container(width: 1, height: 16, color: _C.border),
              );
            }
            final step = _steps[i ~/ 2];
            return Padding(
              padding: EdgeInsets.only(top: i > 0 ? 16 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: _C.green,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        step.$1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _C.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          step.$3,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _C.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Testimonial
// ─────────────────────────────────────────────────────────────────────────────

class _Testimonial extends StatelessWidget {
  const _Testimonial();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.bgPage,
        border: Border(top: BorderSide(color: _C.border, width: 0.5)),
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT PEOPLE SAY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _C.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _C.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stars
                Row(
                  children: List.generate(
                    5,
                    (_) => Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: CustomPaint(
                        size: const Size(10, 10),
                        painter: _StarPainter(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Quote
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.textPrimary,
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(
                        text:
                            '\u201CI used to spend my Sunday evenings chasing contractors. ',
                      ),
                      TextSpan(
                        text: 'Flow cut that down to nothing.',
                        style: TextStyle(color: _C.green),
                      ),
                      TextSpan(text: ' Everything\u2019s just there.\u201D'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Author
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E3A5F),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'MK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Marcus K.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.textPrimary,
                          ),
                        ),
                        Text(
                          'Landlord \u00B7 6 properties',
                          style: TextStyle(
                            fontSize: 10,
                            color: _C.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
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
//  Bottom CTA
// ─────────────────────────────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  const _BottomCta();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.darkBg,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 36),
      child: Column(
        children: [
          // Headline
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.12,
                letterSpacing: -0.6,
              ),
              children: [
                TextSpan(text: 'Stop chasing.\n'),
                TextSpan(
                  text: 'Start flowing.',
                  style: TextStyle(color: _C.greenLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Free for tenants. Straightforward pricing for everyone else.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _C.darkMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),

          // CTA
          GestureDetector(
            onTap: () => context.go(AppRoutes.auth),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _C.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Get started',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.go(AppRoutes.auth),
            child: const Text(
              'Already have an account? Sign in',
              style: TextStyle(fontSize: 11, color: _C.darkSubtle),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Footer
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
      decoration: const BoxDecoration(
        color: _C.darkBg,
        border: Border(top: BorderSide(color: _C.darkBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const _FlowLogo(size: 18),
              const SizedBox(width: 6),
              const Text(
                'Flow',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _C.darkMuted,
                ),
              ),
            ],
          ),
          Row(
            children: const [
              Text('Privacy', style: TextStyle(fontSize: 10, color: _C.darkSubtle)),
              SizedBox(width: 12),
              Text('Terms', style: TextStyle(fontSize: 10, color: _C.darkSubtle)),
              SizedBox(width: 12),
              Text('Contact', style: TextStyle(fontSize: 10, color: _C.darkSubtle)),
            ],
          ),
        ],
      ),
    );
  }
}
