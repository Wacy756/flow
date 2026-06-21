import 'package:flutter/material.dart';

import '../../features/dashboard/providers/dashboard_providers.dart';
import '../../shared/widgets/flow_logo.dart';
import '../theme/app_colors.dart';
import '../theme/dialogs.dart';

/// Gold-standard sidebar used by all role dashboards.
/// Pass [tabs] + [labelOf] + [iconOf] to configure nav items.
class RoleSidebar<T> extends StatelessWidget {
  final UserProfile profile;
  final Color accent;
  final String roleLabel;
  final List<T> tabs;
  final T activeTab;
  final ValueChanged<T> onTabChange;
  final String Function(T) labelOf;
  final IconData Function(T) iconOf;
  final VoidCallback onSignOut;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;

  const RoleSidebar({
    super.key,
    required this.profile,
    required this.accent,
    required this.roleLabel,
    required this.tabs,
    required this.activeTab,
    required this.onTabChange,
    required this.labelOf,
    required this.iconOf,
    required this.onSignOut,
    this.onNotifications,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final initials = profile.fullName.isNotEmpty
        ? profile.fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Logo ─────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 8),
          child: Row(children: [
            AbodeLogo(size: 28),
            const SizedBox(width: 9),
            Text('Abode',
              style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.5)),
          ]),
        ),
        // ── Role chip ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 5, height: 5,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(roleLabel,
                style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        // ── Nav ───────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(children: [
            for (final t in tabs)
              _SidebarNavItem(
                label: labelOf(t),
                icon: iconOf(t),
                active: activeTab == t,
                onTap: () => onTabChange(t),
              ),
          ]),
        ),
        if (onNotifications != null || onSettings != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (onNotifications != null)
                _SidebarActionBtn(icon: Icons.notifications_outlined, onTap: onNotifications!),
              if (onSettings != null) ...[
                const SizedBox(width: 2),
                _SidebarActionBtn(icon: Icons.settings_outlined, onTap: onSettings!),
              ],
            ]),
          ),
          const SizedBox(height: 6),
        ],
        const Spacer(),
        // ── Profile footer ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.border.withValues(alpha: 0.6), width: 0.5)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Center(child: Text(initials,
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.fullName, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(roleLabel, style: TextStyle(color: p.muted, fontSize: 10)),
            ])),
            GestureDetector(
              onTap: () => _confirmSignOut(context, onSignOut),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.logout_outlined, color: p.muted, size: 16),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  static Future<void> _confirmSignOut(BuildContext context, VoidCallback onSignOut) async {
    final ok = await showAbodeConfirmDialog(
      context,
      title: 'Sign out?',
      body: "You'll be returned to the home screen.",
      confirmLabel: 'Sign out',
      isDestructive: true,
      icon: Icons.logout_outlined,
    );
    if (ok == true) onSignOut();
  }
}

// ─── Nav item ─────────────────────────────────────────────────────────────────
class _SidebarNavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _SidebarNavItem({required this.label, required this.icon, required this.active, required this.onTap});
  @override State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

// ─── Action button (bell / settings) ─────────────────────────────────────────
class _SidebarActionBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SidebarActionBtn({required this.icon, required this.onTap});
  @override State<_SidebarActionBtn> createState() => _SidebarActionBtnState();
}

class _SidebarActionBtnState extends State<_SidebarActionBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _hover ? p.text.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 16, color: p.muted),
        ),
      ),
    );
  }
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final a = widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: a ? p.text.withValues(alpha: 0.07)
                : _hover ? p.text.withValues(alpha: 0.03) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              width: 3, height: 15,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: a ? const Color(0xFF22C55E) : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(widget.icon, size: 16, color: a ? p.text : p.muted),
            const SizedBox(width: 9),
            Text(widget.label,
              style: TextStyle(
                color: a ? p.text : p.muted,
                fontSize: 13.5,
                fontWeight: a ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: -0.1,
              )),
          ]),
        ),
      ),
    );
  }
}
