import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, UserAttributes;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/notifications/push_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/animated_page.dart';
import '../../dashboard/models/plan.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../dashboard/widgets/upgrade_sheet.dart';
import '../providers/settings_providers.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _avatarUploading = false;

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final profileAsync = ref.watch(currentProfileProvider);
    final planAsync = ref.watch(currentPlanProvider);
    final notifPrefs = ref.watch(notificationPrefsNotifierProvider).valueOrNull
        ?? const NotificationPrefs();

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: p.sub),
          onPressed: () => context.pop(),
        ),
        title: Text('Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.text,
              letterSpacing: -0.3,
            )),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          final initials = profile.fullName.isNotEmpty
              ? profile.fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
              : '?';

          final accentColor = switch (profile.role) {
            'landlord'   => p.green,
            'tenant'     => const Color(0xFF8B5CF6),
            'contractor' => const Color(0xFFF59E0B),
            _            => const Color(0xFF3B82F6),
          };

          final roleLabel = switch (profile.role) {
            'landlord'   => 'Landlord',
            'tenant'     => 'Tenant',
            'contractor' => 'Contractor',
            'agent'      => 'Agent',
            _            => profile.role,
          };

          return AnimatedPage(
            child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 48),
            children: [

              // ── Avatar hero ─────────────────────────────────────────────
              const SizedBox(height: 8),

              // ── Account ──────────────────────────────────────────────────
              _SectionLabel('ACCOUNT', p),
              _Group(p: p, children: [
                _Row(
                  p: p,
                  icon: Icons.person_outline_rounded,
                  iconColor: p.blue,
                  label: 'Edit Profile',
                  sub: 'Name, phone number',
                  onTap: () => _showEditProfileSheet(context, profile.id, profile.fullName, profile.phone),
                ),
                if (profile.role == 'landlord' || profile.role == 'agent')
                  _Row(
                    p: p,
                    icon: Icons.account_balance_outlined,
                    iconColor: p.green,
                    label: 'Bank Details',
                    sub: profile.bankAccountName != null && profile.bankAccountName!.isNotEmpty
                        ? profile.bankAccountName!
                        : 'For rent payments & deposits',
                    onTap: () => _showBankDetailsSheet(context, profile.id,
                        profile.bankAccountName, profile.bankSortCode, profile.bankAccountNumber),
                  ),
                _Row(
                  p: p,
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  label: 'Change Password',
                  onTap: () => _showChangePasswordSheet(context),
                ),
                _Row(
                  p: p,
                  icon: Icons.notifications_outlined,
                  iconColor: p.amber,
                  label: 'Notifications',
                  trailing: Switch.adaptive(
                    value: notifPrefs.pushEnabled,
                    activeTrackColor: p.green,
                    onChanged: (v) => ref.read(notificationPrefsNotifierProvider.notifier).togglePush(v),
                  ),
                  showChevron: false,
                ),
              ]),

              // ── Plan & Billing (role-aware) ──────────────────────────────
              _SectionLabel('PLAN & BILLING', p),
              if (profile.role == 'landlord' || profile.role == 'agent')
                planAsync.when(
                  loading: () => const SizedBox(
                      height: 2, child: LinearProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (plan) => _Group(p: p, children: [
                    _PlanRow(
                        p: p,
                        plan: plan,
                        onUpgrade: () => showUpgradeSheet(context),
                        onManage: plan.isPaid ? () => _openCustomerPortal(context) : null),
                  ]),
                )
              else if (profile.role == 'contractor')
                _Group(p: p, children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.percent_rounded,
                            color: Color(0xFFF97316), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No subscription fee',
                              style: TextStyle(color: p.text, fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('4% platform fee per completed job',
                              style: TextStyle(color: p.sub, fontSize: 12)),
                        ],
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('FREE',
                            style: TextStyle(color: p.green, fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ])
              else
                // Tenant
                _Group(p: p, children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: p.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.favorite_outline_rounded,
                            color: p.green, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Free for tenants',
                              style: TextStyle(color: p.text, fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('Abode is always free for renters',
                              style: TextStyle(color: p.sub, fontSize: 12)),
                        ],
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('FREE',
                            style: TextStyle(color: p.green, fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ]),

              // ── Appearance ───────────────────────────────────────────────
              _SectionLabel('APPEARANCE', p),
              _Group(p: p, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: p.sub.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.contrast_rounded, color: p.sub, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Theme',
                        style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w500))),
                    // Pill toggle
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(children: [
                        _ThemeChip(label: 'Dark', icon: Icons.dark_mode_outlined,
                            active: isDark, color: p.green,
                            onTap: () => ref.read(themeModeProvider.notifier).setDark()),
                        const SizedBox(width: 4),
                        _ThemeChip(label: 'Light', icon: Icons.light_mode_outlined,
                            active: !isDark, color: p.amber,
                            onTap: () => ref.read(themeModeProvider.notifier).setLight()),
                      ]),
                    ),
                  ]),
                ),
              ]),

              // ── Support ──────────────────────────────────────────────────
              _SectionLabel('SUPPORT & LEGAL', p),
              _Group(p: p, children: [
                _Row(
                  p: p,
                  icon: Icons.help_outline_rounded,
                  iconColor: p.blue,
                  label: 'Help & Support',
                  onTap: () => _launchUrl('mailto:hello@useabode.co.uk'),
                ),
                _Row(
                  p: p,
                  icon: Icons.privacy_tip_outlined,
                  iconColor: p.sub,
                  label: 'Privacy Policy',
                  onTap: () => _launchUrl('https://useabode.co.uk/privacy'),
                ),
                _Row(
                  p: p,
                  icon: Icons.description_outlined,
                  iconColor: p.sub,
                  label: 'Terms of Service',
                  onTap: () => _launchUrl('https://useabode.co.uk/terms'),
                ),
              ]),

              // ── Danger ───────────────────────────────────────────────────
              _SectionLabel('ACCOUNT ACTIONS', p),
              _Group(p: p, children: [
                _Row(
                  p: p,
                  icon: Icons.logout_rounded,
                  iconColor: p.red,
                  iconBg: p.red.withValues(alpha: 0.12),
                  label: 'Sign out',
                  labelColor: p.red,
                  showChevron: false,
                  onTap: () => _signOut(context),
                ),
                _Row(
                  p: p,
                  icon: Icons.delete_forever_outlined,
                  iconColor: p.red,
                  iconBg: p.red.withValues(alpha: 0.08),
                  label: 'Delete account',
                  labelColor: p.red,
                  showChevron: false,
                  onTap: () => _confirmDeleteAccount(context),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ));
        },
      ),
    );
  }

  Future<void> _pickAvatar(String profileId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _avatarUploading = true);
    try {
      final ext = file.extension ?? 'jpg';
      final path = '$profileId/avatar.$ext';
      await supabase.storage.from('avatars').uploadBinary(
        path,
        file.bytes!,
        fileOptions: FileOptions(upsert: true, contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}'),
      );
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      await supabase.from('profiles').update({'avatar_url': '$url?t=${DateTime.now().millisecondsSinceEpoch}'}).eq('id', profileId);
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) {
        showAbodeToast(context, 'Failed to upload photo: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  void _showBankDetailsSheet(BuildContext context, String profileId,
      String? name, String? sortCode, String? accountNumber) {
    showBankDetailsSheet(
      context,
      profileId: profileId,
      currentName: name,
      currentSortCode: sortCode,
      currentAccountNumber: accountNumber,
    ).then((_) => ref.invalidate(currentProfileProvider));
  }

  void _showEditProfileSheet(BuildContext context, String profileId, String currentName, String? currentPhone) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profileId: profileId, currentName: currentName, currentPhone: currentPhone),
    ).then((_) => ref.invalidate(currentProfileProvider));
  }

  void _showChangePasswordSheet(BuildContext context) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _openCustomerPortal(BuildContext context) async {
    try {
      final url = await ref.read(openCustomerPortalProvider.notifier).getUrl();
      if (url == null) throw Exception('No portal URL');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        showAbodeToast(context, 'Could not open billing portal. Try again.', isError: true);
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final confirmed = await showAdaptiveSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeleteAccountSheet(confirmName: profile?.fullName ?? ''),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await supabase.rpc('delete_my_account');
      await PushService.removeToken();
      await supabase.auth.signOut();
      if (context.mounted) context.go(AppRoutes.landing);
    } catch (e) {
      if (context.mounted) {
        showAbodeToast(context, 'Failed to delete account — please try again.', isError: true);
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showAdaptiveSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SignOutSheet(),
    );
    if (confirmed == true && context.mounted) {
      await PushService.removeToken();
      await supabase.auth.signOut();
      if (context.mounted) context.go(AppRoutes.landing);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─── Edit Profile Sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  final String profileId;
  final String currentName;
  final String? currentPhone;
  const _EditProfileSheet({required this.profileId, required this.currentName, this.currentPhone});
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.currentName);
    _phoneCtrl = TextEditingController(text: widget.currentPhone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit Profile', style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _FieldLabel('Full name', p),
            const SizedBox(height: 6),
            _TextField(controller: _nameCtrl, hint: 'Your full name', p: p),
            const SizedBox(height: 14),
            _FieldLabel('Phone number', p),
            const SizedBox(height: 6),
            _TextField(controller: _phoneCtrl, hint: '+44 7700 000000', p: p,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: p.green,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save changes',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await supabase.from('profiles').update({
        'full_name': name,
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      }).eq('id', widget.profileId);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Change Password Sheet ─────────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving       = false;
  bool _obscureNew   = true;
  bool _obscureConf  = true;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Change Password', style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text("You'll receive a link at your email to reset your password, or enter a new one below.",
                style: TextStyle(color: p.muted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 20),
            _FieldLabel('New password', p),
            const SizedBox(height: 6),
            _TextField(
              controller: _newCtrl,
              hint: 'At least 8 characters',
              p: p,
              obscure: _obscureNew,
              onChanged: (_) => setState(() => _error = null),
              suffix: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18, color: p.muted),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Confirm new password', p),
            const SizedBox(height: 6),
            _TextField(
              controller: _confirmCtrl,
              hint: 'Repeat new password',
              p: p,
              obscure: _obscureConf,
              onChanged: (_) => setState(() => _error = null),
              suffix: IconButton(
                icon: Icon(_obscureConf ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18, color: p.muted),
                onPressed: () => setState(() => _obscureConf = !_obscureConf),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: p.red, fontSize: 12)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _saving ? null : _changePassword,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: p.green,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Update password',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final newPw = _newCtrl.text.trim();
    final confPw = _confirmCtrl.text.trim();
    if (newPw.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (newPw != confPw) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPw));
      if (mounted) {
        Navigator.pop(context);
        showAbodeToast(context, 'Password updated');
      }
    } catch (e) {
      setState(() => _error = 'Failed to update password. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Bank Details Sheet ───────────────────────────────────────────────────────

class _BankDetailsSheet extends StatefulWidget {
  final String profileId;
  final String? currentName;
  final String? currentSortCode;
  final String? currentAccountNumber;
  const _BankDetailsSheet({
    required this.profileId,
    this.currentName,
    this.currentSortCode,
    this.currentAccountNumber,
  });
  @override
  State<_BankDetailsSheet> createState() => _BankDetailsSheetState();
}

class _BankDetailsSheetState extends State<_BankDetailsSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _sortCtrl;
  late final TextEditingController _accountCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.currentName ?? '');
    _sortCtrl    = TextEditingController(text: widget.currentSortCode ?? '');
    _accountCtrl = TextEditingController(text: widget.currentAccountNumber ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sortCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bank Details', style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Shared with tenants so they can transfer rent. Also pre-fills holding deposit requests.',
                style: TextStyle(color: p.muted, fontSize: 12, height: 1.4)),
            const SizedBox(height: 20),
            _FieldLabel('Account name', p),
            const SizedBox(height: 6),
            _TextField(controller: _nameCtrl, hint: 'e.g. Bradley Smith', p: p),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FieldLabel('Sort code', p),
                const SizedBox(height: 6),
                _TextField(controller: _sortCtrl, hint: '00-00-00', p: p,
                    keyboardType: TextInputType.number),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _FieldLabel('Account number', p),
                const SizedBox(height: 6),
                _TextField(controller: _accountCtrl, hint: '12345678', p: p,
                    keyboardType: TextInputType.number),
              ])),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: p.green,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save details',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await supabase.from('profiles').update({
        'bank_account_name':   _nameCtrl.text.trim(),
        'bank_sort_code':      _sortCtrl.text.trim(),
        'bank_account_number': _accountCtrl.text.trim(),
      }).eq('id', widget.profileId);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Public entry point for bank details sheet ────────────────────────────────

Future<void> showBankDetailsSheet(
  BuildContext context, {
  required String profileId,
  String? currentName,
  String? currentSortCode,
  String? currentAccountNumber,
}) {
  return showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BankDetailsSheet(
      profileId: profileId,
      currentName: currentName,
      currentSortCode: currentSortCode,
      currentAccountNumber: currentAccountNumber,
    ),
  );
}

// ─── Sign Out Sheet ───────────────────────────────────────────────────────────

class _SignOutSheet extends StatelessWidget {
  const _SignOutSheet();

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 28),

              // Icon
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 20),

              // Title
              Text('Sign out?',
                  style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text("You'll need to sign back in to access your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 14, height: 1.4)),
              const SizedBox(height: 32),

              // Sign out button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('Sign out',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.border),
                  ),
                  child: Center(
                    child: Text('Cancel',
                        style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Delete Account Sheet ─────────────────────────────────────────────────────

class _DeleteAccountSheet extends StatefulWidget {
  final String confirmName;
  const _DeleteAccountSheet({required this.confirmName});
  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _inputCtrl = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() {
      final m = _inputCtrl.text.trim().toLowerCase() ==
          widget.confirmName.trim().toLowerCase();
      if (m != _matches) setState(() => _matches = m);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_outlined, color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 20),

              // Title
              Text('Delete account?',
                  style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text(
                'This is permanent and cannot be undone. All your data, properties, and tenancies will be removed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Name confirmation field
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Type your name to confirm',
                  style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _inputCtrl,
                autofocus: false,
                style: TextStyle(color: p.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.confirmName.isEmpty ? 'Your full name' : widget.confirmName,
                  hintStyle: TextStyle(color: p.muted, fontSize: 15),
                  filled: true,
                  fillColor: p.card,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: p.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _matches ? const Color(0xFFEF4444) : p.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _matches ? const Color(0xFFEF4444) : p.green, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
              const SizedBox(height: 24),

              // Delete button — only active when name matches
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _matches ? 1.0 : 0.4,
                child: GestureDetector(
                  onTap: _matches ? () => Navigator.of(context).pop(true) : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('Delete account',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.border),
                  ),
                  child: Center(
                    child: Text('Cancel',
                        style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final AbodePalette p;
  const _SectionLabel(this.text, this.p);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
    child: Text(text,
        style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
  );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  final AbodePalette p;
  const _Group({required this.children, required this.p});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    decoration: BoxDecoration(
      color: p.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p.border),
      boxShadow: p.cardShadow,
    ),
    child: Column(
      children: children.indexed.map((item) {
        final (i, child) = item;
        if (i == children.length - 1) return child;
        return Column(children: [child, Divider(height: 1, indent: 66, color: p.border)]);
      }).toList(),
    ),
  );
}

class _Row extends StatelessWidget {
  final AbodePalette p;
  final IconData icon;
  final Color iconColor;
  final Color? iconBg;
  final String label;
  final Color? labelColor;
  final String? sub;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _Row({
    required this.p,
    required this.icon,
    required this.iconColor,
    this.iconBg,
    required this.label,
    this.labelColor,
    this.sub,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconBg ?? iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: labelColor ?? p.text, fontSize: 15, fontWeight: FontWeight.w500)),
          if (sub != null) Text(sub!, style: TextStyle(color: p.muted, fontSize: 12)),
        ])),
        if (trailing != null) trailing!
        else if (showChevron) Icon(Icons.chevron_right_rounded, color: p.muted, size: 20),
      ]),
    ),
  );
}

class _PlanRow extends StatelessWidget {
  final AbodePalette p;
  final AbodePlan plan;
  final VoidCallback onUpgrade;
  final VoidCallback? onManage;
  const _PlanRow({required this.p, required this.plan, required this.onUpgrade, this.onManage});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF3B82F6), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${plan.displayName} Plan',
              style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w600)),
          Text(plan == AbodePlan.free ? 'Free forever' : '${plan.price} ${plan.period}',
              style: TextStyle(color: p.muted, fontSize: 12)),
        ])),
        if (onManage != null)
          GestureDetector(
            onTap: onManage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: p.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Manage',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          )
        else if (plan != AbodePlan.pro)
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Upgrade',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: _featureChips(plan, p)),
    ]),
  );

  List<Widget> _featureChips(AbodePlan plan, AbodePalette p) {
    final labels = switch (plan) {
      AbodePlan.free => ['1 property free', 'Messaging', 'Incidents', 'Rent tracking'],
      AbodePlan.essential => ['Unlimited properties', 'Document Vault', 'Legal Letters', 'Full Compliance'],
      AbodePlan.pro => ['White-label', 'API access', 'Team access', 'Priority support'],
    };
    return labels.map((l) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: p.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.green.withValues(alpha: 0.2)),
      ),
      child: Text(l, style: TextStyle(color: p.green, fontSize: 11, fontWeight: FontWeight.w500)),
    )).toList();
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ThemeChip({required this.label, required this.icon, required this.active,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: active ? Border.all(color: color.withValues(alpha: 0.35)) : null,
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: active ? color : Colors.grey),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: active ? color : Colors.grey,
            fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ]),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final AbodePalette p;
  const _FieldLabel(this.text, this.p);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3));
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final AbodePalette p;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  const _TextField({required this.controller, required this.hint, required this.p,
      this.obscure = false, this.keyboardType, this.suffix, this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    onChanged: onChanged,
    style: TextStyle(color: p.text, fontSize: 15),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: p.muted, fontSize: 15),
      suffixIcon: suffix,
      filled: true,
      fillColor: p.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.green, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );
}
