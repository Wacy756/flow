import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show OAuthProvider, AuthChangeEvent;

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/flow_logo.dart';
import '../providers/auth_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Role accent colours (mirrors landing page)
// ─────────────────────────────────────────────────────────────────────────────

const _roleAccent = <String, Color>{
  'landlord':   Color(0xFF4ADE80),
  'tenant':     Color(0xFFEAB308),
  'contractor': Color(0xFFFB923C),
  'agent':      Color(0xFF818CF8),
};

const _roleBg = <String, Color>{
  'landlord':   Color(0xFF0F2D1F),
  'tenant':     Color(0xFF1A1A0A),
  'contractor': Color(0xFF1F0F0A),
  'agent':      Color(0xFF0D0F2A),
};

const _roleBorder = <String, Color>{
  'landlord':   Color(0x334ADE80),
  'tenant':     Color(0x33EAB308),
  'contractor': Color(0x33FB923C),
  'agent':      Color(0x33818CF8),
};

// ─────────────────────────────────────────────────────────────────────────────

class AuthScreen extends ConsumerStatefulWidget {
  final String? initialRole;
  final String initialMode;
  final String? redirect;

  const AuthScreen({
    super.key,
    this.initialRole,
    this.initialMode = 'signup',
    this.redirect,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late String _mode; // 'signup' | 'signin'
  bool _useMagicLink = false;
  String? _selectedRole;
  bool _showPassword = false;
  bool _oauthLoading = false;

  final _formKey        = GlobalKey<FormState>();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _nameCtrl       = TextEditingController();
  final _magicEmailCtrl = TextEditingController();

  late final AnimationController _expandCtrl;
  late final Animation<double>   _expandAnim;

  bool    _showOAuthRolePicker = false;
  String? _oauthSelectedRole;
  final   _oauthNameCtrl = TextEditingController();

  StreamSubscription<dynamic>? _authStateSub;

  @override
  void initState() {
    super.initState();
    _mode         = widget.initialMode;
    _selectedRole = widget.initialRole;

    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _mode == 'signup' ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeInOut,
    );

    _authStateSub =
        supabase.auth.onAuthStateChange.listen(_onAuthStateChange);
  }

  void _onAuthStateChange(dynamic data) {
    if (!mounted) return;
    final event   = data.event as AuthChangeEvent?;
    final session = data.session;
    if (event != AuthChangeEvent.signedIn || session == null) return;

    final user     = session.user;
    final provider = user.appMetadata['provider'] as String?;
    final role     = user.userMetadata?['role'] as String?;

    if (provider != null &&
        provider != 'email' &&
        (role == null || role.isEmpty)) {
      final oauthName = user.userMetadata?['name']     as String? ??
                        user.userMetadata?['full_name'] as String? ?? '';
      setState(() {
        _oauthSelectedRole  = null;
        _oauthNameCtrl.text = oauthName;
        _showOAuthRolePicker = true;
        _oauthLoading        = false;
      });
    }
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    _expandCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _magicEmailCtrl.dispose();
    _oauthNameCtrl.dispose();
    super.dispose();
  }

  // ── Mode ────────────────────────────────────────────────────────────────────

  void _switchMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode         = mode;
      _useMagicLink = false;
    });
    if (mode == 'signup') {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
    }
  }

  // ── Magic Link ───────────────────────────────────────────────────────────────

  Future<void> _sendMagicLink() async {
    final email = _magicEmailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Please enter a valid email address.', isError: true);
      return;
    }
    await ref.read(authNotifierProvider.notifier).sendMagicLink(email);
    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.magicLinkSent) {
      _showSnack('Magic link sent! Check your inbox.');
      ref.read(authNotifierProvider.notifier).reset();
    } else if (authState.status == AuthStatus.error) {
      _showSnack(authState.errorMessage ?? 'An error occurred.', isError: true);
      ref.read(authNotifierProvider.notifier).reset();
    }
  }

  // ── Email / password ─────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_mode == 'signup' && _selectedRole == null) {
      _showSnack('Please select a role to continue', isError: true);
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);

    if (_mode == 'signup') {
      await notifier.signUp(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
        role:     _selectedRole!,
      );
    } else {
      await notifier.signIn(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    }

    final authState = ref.read(authNotifierProvider);
    if (!mounted) return;

    if (authState.status == AuthStatus.success) {
      _showSnack(_mode == 'signup' ? 'Welcome to Flow!' : 'Welcome back!');
      ref.read(authNotifierProvider.notifier).reset();
      context.go(widget.redirect ?? AppRoutes.dashboard);
    } else if (authState.status == AuthStatus.confirmEmail) {
      ref.read(authNotifierProvider.notifier).reset();
      _switchMode('signin');
      _showSnack(
        'Account created! Check your inbox and confirm your email, then sign in.',
      );
    } else if (authState.status == AuthStatus.error) {
      _showSnack(authState.errorMessage ?? 'An error occurred.', isError: true);
      ref.read(authNotifierProvider.notifier).reset();
    }
  }

  // ── OAuth ────────────────────────────────────────────────────────────────────

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    setState(() => _oauthLoading = true);
    await ref.read(authNotifierProvider.notifier).signInWithOAuth(provider);
    if (!mounted) return;
    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.error) {
      setState(() => _oauthLoading = false);
      _showSnack(authState.errorMessage ?? 'Sign-in failed.', isError: true);
      ref.read(authNotifierProvider.notifier).reset();
    }
  }

  Future<void> _submitOAuthRole() async {
    if (_oauthSelectedRole == null) {
      _showSnack('Please select a role to continue.', isError: true);
      return;
    }
    final name = _oauthNameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter your full name.', isError: true);
      return;
    }

    await ref.read(authNotifierProvider.notifier).setOAuthRole(
      role:     _oauthSelectedRole!,
      fullName: name,
    );
    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.error) {
      _showSnack(authState.errorMessage ?? 'An error occurred.', isError: true);
      ref.read(authNotifierProvider.notifier).reset();
    } else {
      ref.read(authNotifierProvider.notifier).reset();
    }
  }

  // ── Snack ────────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: isError
            ? const Color(0xFF2D1515)
            : AppTheme.bgSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.go('/'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 12,
                                  color: AppTheme.textMuted),
                              SizedBox(width: 5),
                              Text('Back',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textMuted,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Logo + wordmark
                    Column(
                      children: const [
                        FlowLogo(size: 42),
                        SizedBox(height: 10),
                        Text(
                          'Flow',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Headline
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _mode == 'signin'
                            ? 'Welcome back'
                            : 'Create your account',
                        key: ValueKey(_mode + 'headline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _mode == 'signin'
                            ? 'Sign in to continue'
                            : _selectedRole != null
                                ? 'Sign up as ${_selectedRole![0].toUpperCase()}${_selectedRole!.substring(1)}'
                                : 'Choose your role to get started',
                        key: ValueKey(_mode + (_selectedRole ?? '')),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Mode toggle
                    _ModeToggle(mode: _mode, onSwitch: _switchMode),
                    const SizedBox(height: 20),

                    // Magic link sub-toggle (sign-in only)
                    if (_mode == 'signin') ...[
                      _MagicLinkToggle(
                        useMagicLink: _useMagicLink,
                        onToggle: (v) => setState(() => _useMagicLink = v),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Magic link form
                    if (_mode == 'signin' && _useMagicLink) ...[
                      AppTextField(
                        controller: _magicEmailCtrl,
                        label: 'Email',
                        hint: 'you@example.com',
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) =>
                            isLoading ? null : _sendMagicLink(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _sendMagicLink,
                          child: isLoading
                              ? const _Spinner()
                              : const Text('Send Magic Link'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "We'll email you a sign-in link — no password needed.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Email / password form
                    if (!(_mode == 'signin' && _useMagicLink))
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sign-up-only fields
                            SizeTransition(
                              sizeFactor: _expandAnim,
                              axisAlignment: -1,
                              child: FadeTransition(
                                opacity: _expandAnim,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (widget.initialRole == null) ...[
                                      const Text(
                                        'Select Role',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _RoleGrid(
                                        selected: _selectedRole,
                                        onSelect: (r) => setState(
                                            () => _selectedRole = r),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    AppTextField(
                                      controller: _nameCtrl,
                                      label: 'Full Name',
                                      hint: 'John Doe',
                                      prefixIcon: Icons.person_outline,
                                      textInputAction: TextInputAction.next,
                                      validator: (v) =>
                                          _mode == 'signup' &&
                                                  (v == null ||
                                                      v.trim().isEmpty)
                                              ? 'Full name is required'
                                              : null,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),

                            AppTextField(
                              controller: _emailCtrl,
                              label: 'Email',
                              hint: 'you@example.com',
                              prefixIcon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            AppTextField(
                              controller: _passwordCtrl,
                              label: 'Password',
                              hint: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: !_showPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) =>
                                  isLoading ? null : _submit(),
                              suffix: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: AppTheme.textMuted,
                                ),
                                onPressed: () => setState(
                                    () => _showPassword = !_showPassword),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submit,
                                child: isLoading
                                    ? const _Spinner()
                                    : Text(_mode == 'signup'
                                        ? 'Create account'
                                        : 'Sign in'),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Divider
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: AppTheme.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted)),
                        ),
                        const Expanded(
                            child: Divider(color: AppTheme.border)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // OAuth buttons
                    _OAuthButton(
                      onPressed: _oauthLoading
                          ? null
                          : () => _signInWithOAuth(OAuthProvider.google),
                      loading: _oauthLoading,
                      icon: const _GoogleIcon(),
                      label: 'Continue with Google',
                    ),

                    if (defaultTargetPlatform == TargetPlatform.iOS ||
                        defaultTargetPlatform == TargetPlatform.macOS) ...[
                      const SizedBox(height: 10),
                      _OAuthButton(
                        onPressed: _oauthLoading
                            ? null
                            : () => _signInWithOAuth(OAuthProvider.apple),
                        loading: false,
                        icon: const Icon(Icons.apple,
                            size: 20, color: AppTheme.textPrimary),
                        label: 'Continue with Apple',
                      ),
                    ],

                    const SizedBox(height: 20),
                    _FooterSwitch(mode: _mode, onSwitch: _switchMode),
                  ],
                ),
              ),
            ),

            // OAuth role-picker overlay
            if (_showOAuthRolePicker)
              _OAuthRolePicker(
                nameCtrl:     _oauthNameCtrl,
                selectedRole: _oauthSelectedRole,
                onRoleSelect: (r) =>
                    setState(() => _oauthSelectedRole = r),
                onSubmit:     _submitOAuthRole,
                isLoading:    isLoading,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

// ── Spinner ────────────────────────────────────────────────────────────────

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(AppTheme.bg),
        ),
      );
}

// ── Mode toggle ────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final String mode;
  final void Function(String) onSwitch;

  const _ModeToggle({required this.mode, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _Tab(label: 'Sign Up',  isActive: mode == 'signup', onTap: () => onSwitch('signup')),
          _Tab(label: 'Sign In',  isActive: mode == 'signin', onTap: () => onSwitch('signin')),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: isActive
                ? Border.all(color: AppTheme.border)
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? AppTheme.textPrimary
                  : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role grid ──────────────────────────────────────────────────────────────

class _RoleGrid extends StatelessWidget {
  final String? selected;
  final void Function(String) onSelect;

  static const _roles = [
    ('landlord',   'Landlord'),
    ('tenant',     'Tenant'),
    ('contractor', 'Contractor'),
    ('agent',      'Agent'),
  ];

  const _RoleGrid({this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 3.0,
      children: _roles
          .map((r) => _RoleChip(
                id: r.$1,
                label: r.$2,
                isSelected: selected == r.$1,
                onTap: () => onSelect(r.$1),
              ))
          .toList(),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String id;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.id,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _roleAccent[id] ?? AppTheme.green;
    final bg     = isSelected ? (_roleBg[id] ?? AppTheme.bgSurface) : AppTheme.bgSurface;
    final border = isSelected
        ? (_roleBorder[id] ?? AppTheme.border)
        : AppTheme.border;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: isSelected ? 1.5 : 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? accent : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Magic-link toggle ──────────────────────────────────────────────────────

class _MagicLinkToggle extends StatelessWidget {
  final bool useMagicLink;
  final void Function(bool) onToggle;

  const _MagicLinkToggle({required this.useMagicLink, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _MagicTab(label: 'Password', isActive: !useMagicLink,
              onTap: () => onToggle(false)),
          _MagicTab(label: 'Magic Link', isActive: useMagicLink,
              onTap: () => onToggle(true)),
        ],
      ),
    );
  }
}

class _MagicTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MagicTab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: isActive ? Border.all(color: AppTheme.border) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Footer switch ──────────────────────────────────────────────────────────

class _FooterSwitch extends StatelessWidget {
  final String mode;
  final void Function(String) onSwitch;

  const _FooterSwitch({required this.mode, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final isSignUp = mode == 'signup';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isSignUp ? 'Already have an account? ' : "Don't have an account? ",
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        GestureDetector(
          onTap: () => onSwitch(isSignUp ? 'signin' : 'signup'),
          child: Text(
            isSignUp ? 'Sign in' : 'Sign up',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── OAuth button ───────────────────────────────────────────────────────────

class _OAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final Widget icon;
  final String label;

  const _OAuthButton({
    required this.onPressed,
    required this.loading,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.bgSurface,
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: AppTheme.border, width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppTheme.green),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      )),
                ],
              ),
      ),
    );
  }
}

// ── Google 'G' icon ────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ── OAuth role-picker overlay ──────────────────────────────────────────────

class _OAuthRolePicker extends StatelessWidget {
  final TextEditingController nameCtrl;
  final String? selectedRole;
  final void Function(String) onRoleSelect;
  final VoidCallback onSubmit;
  final bool isLoading;

  const _OAuthRolePicker({
    required this.nameCtrl,
    required this.selectedRole,
    required this.onRoleSelect,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: FlowLogo(size: 38)),
              const SizedBox(height: 16),
              const Text(
                'One last step',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tell us who you are so we can set up the right dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 28),

              // Name field
              TextField(
                controller: nameCtrl,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Select Role',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              _RoleGrid(
                selected: selectedRole,
                onSelect: onRoleSelect,
              ),
              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSubmit,
                  child: isLoading ? const _Spinner() : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
