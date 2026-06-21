import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../../../core/theme/theme_provider.dart';
import '../providers/dashboard_providers.dart';
import '../../../shared/widgets/flow_logo.dart';

// ─── Public entry point ────────────────────────────────────────────────────────
void showSettingsSheet(
  BuildContext context, {
  required String role,
  required Color accent,
  required VoidCallback onSignOut,
}) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettingsSheet(
      role: role,
      accent: accent,
      onSignOut: onSignOut,
    ),
  );
}

// ─── Abode logo widget (reusable) ──────────────────────────────────────────────
Widget abodeLogo({double size = 28, double radius = 8}) => AbodeLogo(size: size);

// ─── Settings sheet ────────────────────────────────────────────────────────────
class _SettingsSheet extends ConsumerStatefulWidget {
  final String role;
  final Color accent;
  final VoidCallback onSignOut;

  const _SettingsSheet({
    required this.role,
    required this.accent,
    required this.onSignOut,
  });

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  bool _pushNotifications = true;
  bool _emailUpdates = true;

  String get _roleLabel => switch (widget.role) {
    'landlord'   => 'Landlord',
    'tenant'     => 'Tenant',
    'contractor' => 'Contractor',
    _            => 'Agent',
  };

  @override
  Widget build(BuildContext context) {
    final p         = AbodePalette.of(context);
    final isDark    = ref.watch(themeModeProvider) == ThemeMode.dark;
    final profileAsync = ref.watch(currentProfileProvider);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                abodeLogo(size: 32, radius: 9),
                const SizedBox(width: 10),
                Text('Settings',
                  style: TextStyle(
                    color: p.text, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
            Divider(height: 1, color: p.border),

            // ── Scrollable body ──────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Profile card ────────────────────────────────────
                    profileAsync.maybeWhen(
                      data: (profile) {
                        if (profile == null) return const SizedBox.shrink();
                        final initials = profile.fullName.isNotEmpty
                            ? profile.fullName.split(' ')
                                .map((w) => w.isNotEmpty ? w[0] : '')
                                .take(2).join().toUpperCase()
                            : '?';
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: p.border),
                            boxShadow: p.cardShadow,
                          ),
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: widget.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(child: Text(initials,
                                style: TextStyle(
                                  color: widget.accent, fontSize: 16,
                                  fontWeight: FontWeight.w700))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(profile.fullName,
                                  style: TextStyle(
                                    color: p.text, fontSize: 15,
                                    fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis),
                                if (profile.email?.isNotEmpty == true)
                                  Text(profile.email!,
                                    style: TextStyle(color: p.sub, fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            )),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: widget.accent.withValues(alpha: 0.3)),
                              ),
                              child: Text(_roleLabel.toUpperCase(),
                                style: TextStyle(
                                  color: widget.accent, fontSize: 10,
                                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            ),
                          ]),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),

                    // ── Appearance ──────────────────────────────────────
                    _SectionLabel(label: 'APPEARANCE', p: p),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                        boxShadow: p.cardShadow,
                      ),
                      child: Row(children: [
                        // Dark
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                ref.read(themeModeProvider.notifier).setDark(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1C1C1E)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isDark
                                    ? Border.all(color: widget.accent.withValues(alpha: 0.4))
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.dark_mode_outlined,
                                    size: 16,
                                    color: isDark ? widget.accent : p.sub),
                                  const SizedBox(width: 6),
                                  Text('Dark',
                                    style: TextStyle(
                                      color: isDark ? widget.accent : p.sub,
                                      fontSize: 13,
                                      fontWeight: isDark
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Light
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                ref.read(themeModeProvider.notifier).setLight(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isDark
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: !isDark
                                    ? Border.all(color: widget.accent.withValues(alpha: 0.4))
                                    : null,
                                boxShadow: !isDark
                                    ? [const BoxShadow(
                                        color: Color(0x10000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 1))]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.light_mode_outlined,
                                    size: 16,
                                    color: !isDark ? widget.accent : p.sub),
                                  const SizedBox(width: 6),
                                  Text('Light',
                                    style: TextStyle(
                                      color: !isDark ? widget.accent : p.sub,
                                      fontSize: 13,
                                      fontWeight: !isDark
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── Notifications ───────────────────────────────────
                    _SectionLabel(label: 'NOTIFICATIONS', p: p),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                        boxShadow: p.cardShadow,
                      ),
                      child: Column(children: [
                        _SettingsToggleRow(
                          p: p,
                          icon: Icons.notifications_outlined,
                          label: 'Push notifications',
                          sub: 'Maintenance updates & messages',
                          value: _pushNotifications,
                          accent: widget.accent,
                          onChanged: (v) => setState(() => _pushNotifications = v),
                        ),
                        Divider(height: 1, color: p.border),
                        _SettingsToggleRow(
                          p: p,
                          icon: Icons.email_outlined,
                          label: 'Email updates',
                          sub: 'Reports, receipts & summaries',
                          value: _emailUpdates,
                          accent: widget.accent,
                          onChanged: (v) => setState(() => _emailUpdates = v),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── Help & Support ──────────────────────────────────
                    _SectionLabel(label: 'HELP & SUPPORT', p: p),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                        boxShadow: p.cardShadow,
                      ),
                      child: Column(children: [
                        _SettingsLinkRow(
                          p: p,
                          icon: Icons.menu_book_outlined,
                          label: 'Help centre & guides',
                          sub: 'Learn how to use Abode',
                          onTap: () {},
                        ),
                        Divider(height: 1, color: p.border),
                        _SettingsLinkRow(
                          p: p,
                          icon: Icons.support_agent_outlined,
                          label: 'Contact support',
                          sub: 'Get help from our team',
                          onTap: () {},
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── Account ─────────────────────────────────────────
                    _SectionLabel(label: 'ACCOUNT', p: p),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _confirmSignOut(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_outlined,
                                color: Color(0xFFEF4444), size: 18),
                            SizedBox(width: 8),
                            Text('Sign out',
                                style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _confirmDeleteAccount(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                color: p.muted, size: 18),
                            const SizedBox(width: 8),
                            Text('Delete account',
                                style: TextStyle(
                                    color: p.muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Version footer ──────────────────────────────────
                    Center(
                      child: Text('Abode v1.0.0',
                        style: TextStyle(color: p.muted, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showAbodeConfirmDialog(
      context,
      title: 'Delete account?',
      body: 'All your data will be permanently deleted within 30 days as required by GDPR. This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_forever_outlined,
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      widget.onSignOut();
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showAbodeConfirmDialog(
      context,
      title: 'Sign out?',
      body: "You'll be returned to the home screen.",
      confirmLabel: 'Sign out',
      isDestructive: true,
      icon: Icons.logout_outlined,
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
      widget.onSignOut();
    }
  }

}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final AbodePalette p;
  const _SectionLabel({required this.label, required this.p});

  @override
  Widget build(BuildContext context) => Text(label,
    style: TextStyle(
      color: p.muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ));
}

class _SettingsToggleRow extends StatelessWidget {
  final AbodePalette p;
  final IconData icon;
  final String label;
  final String sub;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  const _SettingsToggleRow({
    required this.p,
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Icon(icon, size: 17, color: p.sub),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(sub, style: TextStyle(color: p.muted, fontSize: 11)),
      ])),
      GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44, height: 26,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? accent : p.border,
            borderRadius: BorderRadius.circular(13),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    ]),
  );
}

class _SettingsLinkRow extends StatelessWidget {
  final AbodePalette p;
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _SettingsLinkRow({
    required this.p,
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, size: 17, color: p.sub),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(sub, style: TextStyle(color: p.muted, fontSize: 11)),
        ])),
        Icon(Icons.chevron_right_rounded, color: p.muted, size: 20),
      ]),
    ),
  );
}
