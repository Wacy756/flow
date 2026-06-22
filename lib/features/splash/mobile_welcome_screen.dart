import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../shared/widgets/flow_logo.dart';

/// Native-only welcome screen shown after splash for unauthenticated users.
///
/// The GoRouter 480ms crossfade IS the entrance animation — no separate
/// entrance animation runs here. The Hero 'abode-logo' tag lets the logo
/// smoothly fly from its splash position to here during the crossfade.
class MobileWelcomeScreen extends StatelessWidget {
  const MobileWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bg    = Color(0xFF0C0C0E);
    const white = Color(0xFFF0F0EE);
    const sub   = Color(0xFF6B6B6F);
    const green = Color(0xFF22C55E);
    // Visible but subtle — lighter than before so the outline reads clearly
    const border = Color(0xFF3A3A3F);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 5),

              // Hero logo — animates from splash position during crossfade
              Hero(
                tag: 'abode-logo',
                child: const AbodeLogo(size: 60),
              ),
              const SizedBox(height: 24),
              const Text(
                'Abode',
                style: TextStyle(
                  color: white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Property, simplified.',
                style: TextStyle(
                  color: sub,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
              ),

              const Spacer(flex: 4),

              _Btn(
                label: 'Get started free',
                filled: true,
                onTap: () => context.push('${AppRoutes.auth}?mode=signup'),
                green: green,
                border: border,
                white: white,
              ),
              const SizedBox(height: 12),
              _Btn(
                label: 'Sign in',
                filled: false,
                onTap: () => context.push('${AppRoutes.auth}?mode=signin'),
                green: green,
                border: border,
                white: white,
              ),
              const SizedBox(height: 20),
              Text(
                'Free for tenants · From £3.50/property for landlords',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: sub.withValues(alpha: 0.65),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  final Color green;
  final Color border;
  final Color white;

  const _Btn({
    required this.label,
    required this.filled,
    required this.onTap,
    required this.green,
    required this.border,
    required this.white,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: filled ? green : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.black : white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    ),
  );
}
