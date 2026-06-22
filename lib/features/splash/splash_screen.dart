import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/foundation.dart';

import '../../core/router/app_router.dart';
import '../../core/supabase/supabase_client.dart';
import '../../shared/widgets/flow_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  late final AnimationController _wordCtrl;
  late final Animation<double> _wordOpacity;
  late final Animation<Offset> _wordSlide;

  late final AnimationController _tagCtrl;
  late final Animation<double> _tagOpacity;

  late final AnimationController _exitCtrl;
  late final Animation<double> _exitOpacity;

  bool _authChecked = false;
  bool _animationComplete = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _wordCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _wordOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOut),
    );
    _wordSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOutCubic));

    _tagCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tagOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut),
    );

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );

    _runSequence();
    _checkAuth();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 80));
    await _wordCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 60));
    await _tagCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _animationComplete = true;
    _maybeExit();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _authChecked = true;
    _maybeExit();
  }

  void _maybeExit() {
    if (!_animationComplete || !_authChecked) return;
    _exit();
  }

  Future<void> _exit() async {
    if (!mounted) return;
    final isAuthed = supabase.auth.currentSession != null;
    if (isAuthed) {
      context.go(AppRoutes.dashboard);
      return;
    }
    if (!kIsWeb) {
      // Fade out splash content before revealing the welcome screen so the
      // transition feels like one continuous animation rather than a hard cut.
      await _exitCtrl.forward();
      if (!mounted) return;
    }
    context.go(kIsWeb ? AppRoutes.landing : AppRoutes.welcome);
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _wordCtrl.dispose();
    _tagCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0C0C0E);

    return Scaffold(
      backgroundColor: bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_logoCtrl, _wordCtrl, _tagCtrl, _exitCtrl]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _exitOpacity,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: const AbodeLogo(size: 72),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SlideTransition(
                    position: _wordSlide,
                    child: FadeTransition(
                      opacity: _wordOpacity,
                      child: const Text(
                        'Abode',
                        style: TextStyle(
                          color: Color(0xFFF0F0EE),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _tagOpacity,
                    child: const Text(
                      'Property, simplified.',
                      style: TextStyle(
                        color: Color(0xFF555558),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
