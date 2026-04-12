import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens — self-contained, does not affect rest of app
// ─────────────────────────────────────────────────────────────────────────────

class _T {
  // Brand
  static const Color indigo     = Color(0xFF4F46E5);
  static const Color indigoDark = Color(0xFF3730A3);
  static const Color indigoFade = Color(0xFFEEF2FF);
  static const Color emerald    = Color(0xFF059669);
  static const Color violet     = Color(0xFF7C3AED);
  static const Color amber      = Color(0xFFD97706);

  // Per-role palette [icon gradient start, end, glow]
  static const Map<String, List<Color>> role = {
    'landlord':   [Color(0xFF4F46E5), Color(0xFF6D28D9)],
    'tenant':     [Color(0xFF059669), Color(0xFF0D9488)],
    'contractor': [Color(0xFFF59E0B), Color(0xFFD97706)],
    'agent':      [Color(0xFF7C3AED), Color(0xFFDB2777)],
  };

  // Surface tokens
  final bool isDark;
  final Color bg;
  final Color bgAlt;
  final Color surface;
  final Color surfaceHover;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color shadowColor;

  const _T({
    required this.isDark,
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.surfaceHover,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.shadowColor,
  });

  static const _T _light = _T(
    isDark: false,
    bg: Color(0xFFF7F7F9),
    bgAlt: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF0F0F5),
    border: Color(0xFFE4E4E7),
    borderStrong: Color(0xFFD4D4D8),
    textPrimary: Color(0xFF09090B),
    textSecondary: Color(0xFF3F3F46),
    textMuted: Color(0xFF71717A),
    shadowColor: Color(0x14000000),
  );

  static const _T _dark = _T(
    isDark: true,
    bg: Color(0xFF09090B),
    bgAlt: Color(0xFF111113),
    surface: Color(0xFF18181B),
    surfaceHover: Color(0xFF27272A),
    border: Color(0xFF27272A),
    borderStrong: Color(0xFF3F3F46),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    shadowColor: Color(0x40000000),
  );

  static _T of(bool isDark) => isDark ? _dark : _light;
}

// ─────────────────────────────────────────────────────────────────────────────
//  InheritedWidget scope
// ─────────────────────────────────────────────────────────────────────────────

class _Scope extends InheritedWidget {
  final _T t;
  const _Scope({required this.t, required super.child});
  static _T of(BuildContext ctx) =>
      ctx.dependOnInheritedWidgetOfExactType<_Scope>()!.t;
  @override
  bool updateShouldNotify(_Scope old) => t != old.t;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Root screen
// ─────────────────────────────────────────────────────────────────────────────

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isDark = false;

  @override
  Widget build(BuildContext context) {
    final t = _T.of(_isDark);
    return _Scope(
      t: t,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Stack(
            children: [
              // Background glow decoration
              Positioned(
                top: -60,
                left: -80,
                child: _GlowCircle(color: _T.indigo, size: 340, opacity: t.isDark ? 0.10 : 0.07),
              ),
              Positioned(
                top: 120,
                right: -100,
                child: _GlowCircle(color: _T.violet, size: 260, opacity: t.isDark ? 0.07 : 0.05),
              ),
              // Main content
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 52),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _TopBar(),
                    SizedBox(height: 52),
                    _Hero(),
                    SizedBox(height: 48),
                    _RoleGrid(),
                    SizedBox(height: 52),
                    _Features(),
                    SizedBox(height: 40),
                    _Footer(),
                  ],
                ),
              ),
              // Theme toggle
              Positioned(
                top: 14,
                right: 20,
                child: _ThemeToggle(
                  isDark: _isDark,
                  onToggle: () => setState(() => _isDark = !_isDark),
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
//  Background glow
// ─────────────────────────────────────────────────────────────────────────────

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowCircle({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top bar — logo only (toggle is in stack)
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final t = _Scope.of(context);
    return Row(
      children: [
        // Logo mark
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_T.indigo, _T.violet],
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: _T.indigo.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'F',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Flow',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Theme toggle
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;
  const _ThemeToggle({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = _Scope.of(context);
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.border),
          boxShadow: [BoxShadow(color: t.shadowColor, blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 16,
            color: t.textMuted,
          ),
        ),
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
    final t = _Scope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: t.isDark
                ? _T.indigo.withValues(alpha: 0.15)
                : _T.indigoFade,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _T.indigo.withValues(alpha: t.isDark ? 0.3 : 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _T.emerald,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'AI-Powered Property Management',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: t.isDark ? _T.indigo.withValues(alpha: 0.9) : _T.indigoDark,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Headline with gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1B4B), _T.indigo, _T.violet],
            stops: [0.0, 0.5, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'Property\nmanagement,\nreimagined.',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.08,
              letterSpacing: -2.0,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Subtitle
        Text(
          'The all-in-one platform that connects landlords,\ntenants, and contractors — powered by AI.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: t.textSecondary,
            height: 1.65,
            letterSpacing: -0.1,
          ),
        ),

        const SizedBox(height: 12),

        // Stats row
        Row(
          children: [
            _StatPill(label: 'Maintenance', icon: Icons.build_circle_outlined, color: _T.emerald),
            const SizedBox(width: 8),
            _StatPill(label: 'Contractors', icon: Icons.handyman_outlined, color: _T.violet),
            const SizedBox(width: 8),
            _StatPill(label: 'AI-Powered', icon: Icons.auto_awesome_outlined, color: _T.amber),
          ],
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatPill({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = _Scope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: t.shadowColor, blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: t.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Role grid
// ─────────────────────────────────────────────────────────────────────────────

class _RoleConfig {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  const _RoleConfig({required this.id, required this.label, required this.description, required this.icon});
}

const _roles = [
  _RoleConfig(id: 'landlord',   label: 'Landlord',   description: 'Manage properties & tenancies',  icon: Icons.apartment_outlined),
  _RoleConfig(id: 'tenant',     label: 'Tenant',      description: 'View your home & report issues', icon: Icons.house_outlined),
  _RoleConfig(id: 'contractor', label: 'Contractor',  description: 'Find jobs & manage your work',   icon: Icons.handyman_outlined),
  _RoleConfig(id: 'agent',      label: 'Agent',       description: 'Oversee your full portfolio',    icon: Icons.groups_outlined),
];

class _RoleGrid extends StatelessWidget {
  const _RoleGrid();

  @override
  Widget build(BuildContext context) {
    final t = _Scope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GET STARTED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: t.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose your role to continue',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.22,
          children: _roles.map((r) => _RoleCard(config: r)).toList(),
        ),
      ],
    );
  }
}

class _RoleCard extends StatefulWidget {
  final _RoleConfig config;
  const _RoleCard({required this.config});
  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = _Scope.of(context);
    final colors = _T.role[widget.config.id]!;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        context.push('${AppRoutes.auth}?role=${widget.config.id}&mode=signup');
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed
                  ? colors[0].withValues(alpha: 0.4)
                  : t.border,
            ),
            boxShadow: [
              BoxShadow(
                color: t.shadowColor,
                blurRadius: _pressed ? 4 : 16,
                offset: const Offset(0, 4),
              ),
              if (!t.isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.config.icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Text(
                widget.config.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.config.description,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: t.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: t.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Features
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureItem {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _FeatureItem({required this.icon, required this.title, required this.desc, required this.color});
}

const _featureItems = [
  _FeatureItem(icon: Icons.build_circle_outlined,    title: 'Maintenance',     desc: 'AI-triaged requests routed to the right contractor',   color: _T.emerald),
  _FeatureItem(icon: Icons.forum_outlined,           title: 'Communication',   desc: 'Centralised messaging between all parties',            color: _T.indigo),
  _FeatureItem(icon: Icons.receipt_long_outlined,    title: 'Rent Collection', desc: 'Automated invoicing and payment tracking',             color: _T.amber),
  _FeatureItem(icon: Icons.folder_open_outlined,     title: 'Documents',       desc: 'Store compliance docs, EPC, gas safety and more',      color: _T.violet),
  _FeatureItem(icon: Icons.engineering_outlined,     title: 'Contractors',     desc: 'Find vetted local contractors with one tap',           color: Color(0xFF0EA5E9)),
  _FeatureItem(icon: Icons.auto_awesome_outlined,    title: 'AI Automation',   desc: 'Let AI handle scheduling, reminders, and summaries',   color: _T.amber),
];

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    final t = _Scope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.isDark ? t.surface : t.bgAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(color: t.shadowColor, blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CORE FEATURES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: t.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Everything you need\nto manage at scale',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
              letterSpacing: -0.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate((_featureItems.length / 2).ceil(), (row) {
            final left = _featureItems[row * 2];
            final hasRight = row * 2 + 1 < _featureItems.length;
            final right = hasRight ? _featureItems[row * 2 + 1] : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _FeatureRow(item: left)),
                  const SizedBox(width: 16),
                  Expanded(child: right != null ? _FeatureRow(item: right) : const SizedBox()),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = _Scope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: t.isDark ? 0.15 : 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Icon(item.icon, size: 15, color: item.color),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.desc,
                style: TextStyle(
                  fontSize: 10.5,
                  color: t.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final t = _Scope.of(context);
    return Center(
      child: Text(
        'Flow — Property management, reimagined.',
        style: TextStyle(
          fontSize: 11,
          color: t.textMuted,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
