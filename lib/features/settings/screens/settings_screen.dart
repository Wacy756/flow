import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/push_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  bool _nameDirty = false;
  bool _nameSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final prefsAsync  = ref.watch(notificationPrefsNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPage,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppTheme.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.green)),
        error: (_, __) => const Center(
            child: Text('Could not load profile.',
                style: TextStyle(color: AppTheme.textSecondary))),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          // Seed name controller once
          if (_nameController.text.isEmpty) {
            _nameController.text = profile.fullName;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Profile ──────────────────────────────────
              _SectionHeader(icon: Icons.person_outline, title: 'Profile'),
              const SizedBox(height: 12),
              _SectionCard(
                children: [
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: 16),
                  const _FieldLabel('Display name'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Your name',
                      hintStyle: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 14),
                      filled: true,
                      fillColor: AppTheme.bgPage,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppTheme.green, width: 1.5),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() => _nameDirty = v.trim() != profile.fullName);
                    },
                  ),
                  if (_nameDirty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nameSaving ? null : () => _saveName(profile),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.green,
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _nameSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Text(
                                'Save Name',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const _FieldLabel('Email'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgPage,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.border, width: 1),
                    ),
                    child: Text(
                      profile.email ?? 'No email',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Notifications ─────────────────────────────
              _SectionHeader(
                  icon: Icons.notifications_outlined,
                  title: 'Push Notifications'),
              const SizedBox(height: 12),
              prefsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
                data: (prefs) => _NotificationPrefsCard(
                    prefs: prefs, role: profile.role),
              ),

              const SizedBox(height: 28),

              // ── Account ───────────────────────────────────
              _SectionHeader(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Account'),
              const SizedBox(height: 12),
              _SectionCard(
                children: [
                  _ActionRow(
                    icon: Icons.logout_outlined,
                    label: 'Sign out',
                    color: AppTheme.textSecondary,
                    onTap: () => _signOut(context),
                  ),
                  const _RowDivider(),
                  _ActionRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete account',
                    color: Colors.red,
                    onTap: () => _confirmDelete(context),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveName(UserProfile profile) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == profile.fullName) return;

    setState(() => _nameSaving = true);
    final ok = await ref
        .read(updateDisplayNameProvider.notifier)
        .saveName(name);

    if (!mounted) return;
    setState(() {
      _nameSaving = false;
      _nameDirty = false;
    });

    if (ok) {
      ref.invalidate(currentProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name updated'),
          backgroundColor: AppTheme.darkBg,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update name. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await PushService.removeToken();
    await supabase.auth.signOut();
    if (context.mounted) context.go(AppRoutes.landing);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete account?',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final ok = await ref
        .read(deleteAccountProvider.notifier)
        .deleteAccount();


    if (context.mounted) {
      if (ok) {
        context.go(AppRoutes.landing);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete account. Please contact support.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Notification preferences card
// ---------------------------------------------------------------------------

class _NotificationPrefsCard extends ConsumerWidget {
  final NotificationPrefs prefs;
  final String role;
  const _NotificationPrefsCard({required this.prefs, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(notificationPrefsNotifierProvider.notifier);

    void toggle(NotificationPrefs updated) {
      notifier.save(updated);
    }

    return _SectionCard(
      children: [
        // Master toggle
        _ToggleRow(
          icon: Icons.notifications_active_outlined,
          label: 'Enable push notifications',
          value: prefs.pushEnabled,
          onChanged: (v) =>
              toggle(prefs.copyWith(pushEnabled: v)),
        ),
        if (prefs.pushEnabled) ...[
          const _RowDivider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            child: Text(
              'NOTIFY ME ABOUT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          _ToggleRow(
            icon: Icons.build_outlined,
            label: 'Maintenance updates',
            value: prefs.pushMaintenance,
            onChanged: (v) =>
                toggle(prefs.copyWith(pushMaintenance: v)),
          ),
          const _RowDivider(),
          _ToggleRow(
            icon: Icons.payments_outlined,
            label: 'Rent reminders',
            value: prefs.pushRent,
            onChanged: (v) =>
                toggle(prefs.copyWith(pushRent: v)),
          ),
          const _RowDivider(),
          _ToggleRow(
            icon: Icons.verified_outlined,
            label: 'Compliance alerts',
            value: prefs.pushCompliance,
            onChanged: (v) =>
                toggle(prefs.copyWith(pushCompliance: v)),
          ),
          if (role == 'landlord' || role == 'agent') ...[
            const _RowDivider(),
            _ToggleRow(
              icon: Icons.person_add_outlined,
              label: 'New applications',
              value: prefs.pushApplications,
              onChanged: (v) =>
                  toggle(prefs.copyWith(pushApplications: v)),
            ),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.0,
            ),
          ),
        ],
      );
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initial = profile.fullName.isNotEmpty
        ? profile.fullName[0].toUpperCase()
        : '?';

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.roleBg(profile.role),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.roleBg(profile.role),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  profile.role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.4,
        ),
      );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.green,
            inactiveThumbColor: AppTheme.textMuted,
            inactiveTrackColor: AppTheme.border,
          ),
        ],
      );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      );
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppTheme.border.withValues(alpha: 0.5));
}
