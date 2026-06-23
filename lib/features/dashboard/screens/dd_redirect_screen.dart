import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

class DdRedirectScreen extends StatefulWidget {
  final bool success;
  final String? tenancyId;

  const DdRedirectScreen({super.key, required this.success, this.tenancyId});

  @override
  State<DdRedirectScreen> createState() => _DdRedirectScreenState();
}

class _DdRedirectScreenState extends State<DdRedirectScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) context.go(AppRoutes.dashboard);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);
    final success = widget.success;

    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (success ? const Color(0xFF22C55E) : const Color(0xFFEF4444))
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                  color: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                success ? 'Direct Debit authorised' : 'Direct Debit cancelled',
                style: TextStyle(
                  color: p.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                success
                    ? 'Your mandate is being set up. Your landlord will be notified once it\'s active.'
                    : 'No mandate was created. You can set one up again from the app.',
                style: TextStyle(color: p.sub, fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: Text(
                  'Go to app',
                  style: TextStyle(color: p.teal, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
