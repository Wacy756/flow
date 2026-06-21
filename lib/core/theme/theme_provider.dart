import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the active [ThemeMode] for the whole app.
///
/// Defaults to [ThemeMode.dark] to preserve the original aesthetic.
/// Toggle via `ref.read(themeModeProvider.notifier).toggle()`.
final themeModeProvider = StateNotifierProvider<_ThemeModeNotifier, ThemeMode>(
    (_) => _ThemeModeNotifier());

class _ThemeModeNotifier extends StateNotifier<ThemeMode> {
  _ThemeModeNotifier() : super(ThemeMode.dark);

  void setDark()  => state = ThemeMode.dark;
  void setLight() => state = ThemeMode.light;

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

  bool get isDark => state == ThemeMode.dark;
}
