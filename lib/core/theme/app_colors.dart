import 'package:flutter/material.dart';

class AbodePalette {
  final Color bg;
  final Color surface;
  final Color card;
  final Color border;
  final Color text;
  final Color sub;
  final Color muted;
  final Color purple;
  final Color green;
  final Color red;
  final Color amber;
  final Color blue;
  final Color orange;
  final Color teal;
  final List<BoxShadow> cardShadow;

  const AbodePalette._({
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.text,
    required this.sub,
    required this.muted,
    required this.purple,
    required this.green,
    required this.red,
    required this.amber,
    required this.blue,
    required this.orange,
    required this.teal,
    this.cardShadow = const [],
  });

  // ── Dark mode — neutral, accent colours pop cleanly ──────────────────────────
  static const AbodePalette dark = AbodePalette._(
    bg:      Color(0xFF0C0C0E),
    surface: Color(0xFF141416),
    card:    Color(0xFF1C1C1E),
    border:  Color(0xFF2A2A2E),
    text:    Color(0xFFF0F0EE),
    sub:     Color(0xFF888888),
    muted:   Color(0xFF555558),
    purple:  Color(0xFFA855F7),
    green:   Color(0xFF22C55E),
    red:     Color(0xFFEF4444),
    amber:   Color(0xFFFBBF24),
    blue:    Color(0xFF3B82F6),
    orange:  Color(0xFFF97316),
    teal:    Color(0xFF14B8A6),
  );

  // ── Light mode — clean neutral, works with all role accents ──────────────────
  static const AbodePalette light = AbodePalette._(
    bg:      Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    card:    Color(0xFFFFFFFF),
    border:  Color(0xFFE5E5EA),
    text:    Color(0xFF1C1C1E),
    sub:     Color(0xFF636366),
    muted:   Color(0xFFAEAEB2),
    purple:  Color(0xFF7C3AED),
    green:   Color(0xFF15803D),
    red:     Color(0xFFDC2626),
    amber:   Color(0xFFD97706),
    blue:    Color(0xFF1D4ED8),
    orange:  Color(0xFFEA580C),
    teal:    Color(0xFF0F766E),
    cardShadow: [
      BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2)),
      BoxShadow(color: Color(0x08000000), blurRadius: 24, spreadRadius: -4, offset: Offset(0, 8)),
    ],
  );

  static AbodePalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? light : dark;
}