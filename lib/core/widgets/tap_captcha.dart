import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

typedef _Item = ({String label, IconData icon});

const List<_Item> _kPool = [
  (label: 'house',    icon: Icons.home_rounded),
  (label: 'key',      icon: Icons.key_rounded),
  (label: 'calendar', icon: Icons.calendar_today_rounded),
  (label: 'document', icon: Icons.description_rounded),
  (label: 'lock',     icon: Icons.lock_rounded),
  (label: 'person',   icon: Icons.person_rounded),
  (label: 'wrench',   icon: Icons.handyman_rounded),
  (label: 'leaf',     icon: Icons.eco_rounded),
  (label: 'star',     icon: Icons.star_rounded),
  (label: 'envelope', icon: Icons.mail_rounded),
  (label: 'bolt',     icon: Icons.bolt_rounded),
  (label: 'flag',     icon: Icons.flag_rounded),
];

/// Single-tap human verification widget. Shows 4 randomised icons;
/// the user taps the one matching the text prompt.
/// On success, [onVerified] fires. Wrong tap reshuffles after 700 ms.
class TapCaptcha extends StatefulWidget {
  final VoidCallback onVerified;

  const TapCaptcha({super.key, required this.onVerified});

  @override
  State<TapCaptcha> createState() => _TapCaptchaState();
}

class _TapCaptchaState extends State<TapCaptcha> {
  late List<_Item> _choices;
  late String _target;
  bool _failed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _reshuffle();
  }

  void _reshuffle() {
    final rng = Random.secure();
    final pool = List<_Item>.of(_kPool)..shuffle(rng);
    _choices = pool.take(4).toList();
    _target = _choices[rng.nextInt(4)].label;
    _failed = false;
    _done = false;
  }

  void _onTap(_Item item) {
    if (_done) return;
    if (item.label == _target) {
      setState(() => _done = true);
      widget.onVerified();
      return;
    }
    setState(() => _failed = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(_reshuffle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AbodePalette.of(context);

    final promptColor = _done
        ? const Color(0xFF10B981)
        : _failed
            ? const Color(0xFFEF4444)
            : p.sub;

    final promptText = _done
        ? 'Verified'
        : _failed
            ? 'Not quite — try again'
            : 'Tap the $_target';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              promptText,
              key: ValueKey(promptText),
              style: TextStyle(
                color: promptColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (_done) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 16),
          ],
        ]),
        const SizedBox(height: 10),
        Row(
          children: _choices.map((item) {
            final isCorrect = _done && item.label == _target;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _onTap(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    height: 56,
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? const Color(0xFF10B981).withValues(alpha: 0.08)
                          : p.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCorrect
                            ? const Color(0xFF10B981).withValues(alpha: 0.45)
                            : _failed
                                ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                : p.border,
                        width: isCorrect ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(
                      item.icon,
                      color: isCorrect ? const Color(0xFF10B981) : p.sub,
                      size: 22,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          'Human verification',
          style: TextStyle(color: p.muted, fontSize: 10, letterSpacing: 0.3),
        ),
      ],
    );
  }
}
