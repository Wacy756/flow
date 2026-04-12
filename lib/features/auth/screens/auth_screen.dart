import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/auth_notifier.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String? initialRole;
  final String initialMode;

  const AuthScreen({
    super.key,
    this.initialRole,
    this.initialMode = 'signup',
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

  // Animate the sign-up-only section in/out
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
      context.go(AppRoutes.dashboard);
    } else if (state.status == AuthStatus.confirmEmail) {
      // Email confirmation required — stay on screen, switch to sign-in
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
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.primaryDark,
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background gradient blobs — mirrors the web app's decorative circles
          _BackgroundBlobs(),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back to home
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go(AppRoutes.landing),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back to home'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CardHeader(mode: _mode, selectedRole: _selectedRole),
                            const SizedBox(height: 20),
                            _ModeToggle(mode: _mode, onSwitch: _switchMode),
                            const SizedBox(height: 20),

                            // Sign-up-only fields: animated expand/collapse
                            SizeTransition(
                              sizeFactor: _expandAnim,
                              axisAlignment: -1,
                              child: FadeTransition(
                                opacity: _expandAnim,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Role selector (hidden when role pre-selected)
                                    if (widget.initialRole == null) ...[
                                      Text(
                                        'Select Role',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge,
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

                            // Email
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

                            // Password
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
                            _SubmitButton(
                              mode: _mode,
                              isLoading: isLoading,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 20),

                            // Footer switch
                            _FooterSwitch(
                              mode: _mode,
                              onSwitch: _switchMode,
                            ),
                          ],
                        ),
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

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _BackgroundBlobs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-left blob
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom-right blob
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryDark.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _CardHeader extends StatelessWidget {
  final String mode;
  final String? selectedRole;

  const _CardHeader({required this.mode, this.selectedRole});

  String get _subtitle {
    if (mode == 'signin') return 'Sign in to continue';
    if (selectedRole != null) {
      return 'Sign up as ${selectedRole![0].toUpperCase()}${selectedRole!.substring(1)}';
    }
    return 'Choose your role to sign up';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.3),
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
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                mode == 'signup' ? 'Create account' : 'Welcome back',
                key: ValueKey(mode),
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _subtitle,
                key: ValueKey(_subtitle),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Tab(label: 'Sign Up', isActive: mode == 'signup',
              onTap: () => onSwitch('signup')),
          _Tab(label: 'Sign In', isActive: mode == 'signin',
              onTap: () => onSwitch('signin')),
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
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SubmitButton extends StatelessWidget {
  final String mode;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.mode,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isLoading ? null : AppTheme.brandGradient,
        color: isLoading ? AppTheme.primary.withValues(alpha: 0.6) : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                mode == 'signup' ? 'Create account' : 'Sign in',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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
          style: Theme.of(context).textTheme.bodySmall,
        ),
        GestureDetector(
          onTap: () => onSwitch(isSignUp ? 'signin' : 'signup'),
          child: Text(
            isSignUp ? 'Sign in' : 'Sign up',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
