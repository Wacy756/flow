import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/flow_logo.dart';
import '../providers/auth_notifier.dart';

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
  String? _selectedRole;
  bool _showPassword = false;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
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
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _switchMode(String mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == 'signup') {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_mode == 'signup' && _selectedRole == null) {
      _showSnack('Please select a role to continue', isError: true);
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);

    if (_mode == 'signup') {
      await notifier.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
        role: _selectedRole!,
      );
    } else {
      await notifier.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    }

    final state = ref.read(authNotifierProvider);
    if (!mounted) return;

    if (state.status == AuthStatus.success) {
      _showSnack(_mode == 'signup' ? 'Welcome to Flow!' : 'Welcome back!');
      ref.read(authNotifierProvider.notifier).reset();
      context.go(widget.redirect ?? AppRoutes.dashboard);
    } else if (state.status == AuthStatus.confirmEmail) {
      ref.read(authNotifierProvider.notifier).reset();
      _switchMode('signin');
      _showSnack(
        'Account created! Check your inbox and confirm your email, then sign in.',
      );
    } else if (state.status == AuthStatus.error) {
      _showSnack(state.errorMessage ?? 'An error occurred.', isError: true);
      ref.read(authNotifierProvider.notifier).reset();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.darkBg : AppTheme.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.go('/'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Logo + wordmark
                Column(
                  children: [
                    const FlowLogo(size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      'Flow',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Headline
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _mode == 'signin' ? 'Welcome back' : 'Create your account',
                    key: ValueKey(_mode + 'headline'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
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

                // Form
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.initialRole == null) ...[
                                const Text(
                                  'Select Role',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _RoleGrid(
                                  selected: _selectedRole,
                                  onSelect: (r) =>
                                      setState(() => _selectedRole = r),
                                ),
                                const SizedBox(height: 16),
                              ],
                              AppTextField(
                                controller: _nameCtrl,
                                label: 'Full Name',
                                hint: 'John Doe',
                                prefixIcon: Icons.person_outline,
                                textInputAction: TextInputAction.next,
                                validator: (v) => _mode == 'signup' &&
                                        (v == null || v.trim().isEmpty)
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
                          if (!v.contains('@')) return 'Enter a valid email';
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
                        onFieldSubmitted: (_) => isLoading ? null : _submit(),
                        suffix: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
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

                      // Submit button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Text(
                                  _mode == 'signup'
                                      ? 'Create account'
                                      : 'Sign in',
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Footer switch
                      _FooterSwitch(mode: _mode, onSwitch: _switchMode),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ModeToggle extends StatelessWidget {
  final String mode;
  final void Function(String) onSwitch;

  const _ModeToggle({required this.mode, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Sign Up',
            isActive: mode == 'signup',
            onTap: () => onSwitch('signup'),
          ),
          _Tab(
            label: 'Sign In',
            isActive: mode == 'signin',
            onTap: () => onSwitch('signin'),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.bgSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: isActive
                ? Border.all(color: AppTheme.border, width: 0.5)
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RoleGrid extends StatelessWidget {
  final String? selected;
  final void Function(String) onSelect;

  static const _roles = [
    ('landlord', 'Landlord'),
    ('tenant', 'Tenant'),
    ('contractor', 'Contractor'),
    ('agent', 'Agent'),
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
      childAspectRatio: 3.2,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.green : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.green : AppTheme.border,
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

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
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
