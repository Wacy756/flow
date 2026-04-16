import 'dart:developer' as dev;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/supabase/supabase_client.dart';

part 'settings_providers.g.dart';

// ============================================================
// Settings providers
// ============================================================

// ── Display-name edit ─────────────────────────────────────

@riverpod
class UpdateDisplayName extends _$UpdateDisplayName {
  @override
  Future<void> build() async {}

  Future<bool> saveName(String newName) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await supabase
          .from('profiles')
          .update({'full_name': newName})
          .eq('id', userId);
      return true;
    } catch (e, st) {
      dev.log('UpdateDisplayName failed',
          name: 'Settings', error: e, stackTrace: st);
      return false;
    }
  }
}

// ── Notification preferences ──────────────────────────────

class NotificationPrefs {
  final bool pushEnabled;
  final bool pushMaintenance;
  final bool pushRent;
  final bool pushCompliance;
  final bool pushApplications;

  const NotificationPrefs({
    this.pushEnabled = true,
    this.pushMaintenance = true,
    this.pushRent = true,
    this.pushCompliance = true,
    this.pushApplications = true,
  });

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? pushMaintenance,
    bool? pushRent,
    bool? pushCompliance,
    bool? pushApplications,
  }) =>
      NotificationPrefs(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        pushMaintenance: pushMaintenance ?? this.pushMaintenance,
        pushRent: pushRent ?? this.pushRent,
        pushCompliance: pushCompliance ?? this.pushCompliance,
        pushApplications: pushApplications ?? this.pushApplications,
      );

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      NotificationPrefs(
        pushEnabled: json['push_enabled'] as bool? ?? true,
        pushMaintenance: json['push_maintenance'] as bool? ?? true,
        pushRent: json['push_rent'] as bool? ?? true,
        pushCompliance: json['push_compliance'] as bool? ?? true,
        pushApplications: json['push_applications'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'push_enabled': pushEnabled,
        'push_maintenance': pushMaintenance,
        'push_rent': pushRent,
        'push_compliance': pushCompliance,
        'push_applications': pushApplications,
      };
}

@riverpod
class NotificationPrefsNotifier extends _$NotificationPrefsNotifier {
  @override
  Future<NotificationPrefs> build() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return const NotificationPrefs();

    try {
      final row = await supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return const NotificationPrefs();
      return NotificationPrefs.fromJson(row);
    } catch (e, st) {
      dev.log('Load notification prefs failed',
          name: 'Settings', error: e, stackTrace: st);
      return const NotificationPrefs();
    }
  }

  Future<void> save(NotificationPrefs prefs) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Optimistic update
    state = AsyncData(prefs);

    try {
      await supabase.from('notification_preferences').upsert(
        {'user_id': userId, ...prefs.toJson()},
        onConflict: 'user_id',
      );
    } catch (e, st) {
      dev.log('Save notification prefs failed',
          name: 'Settings', error: e, stackTrace: st);
      ref.invalidateSelf();
    }
  }
}

// ── Account deletion ──────────────────────────────────────

@riverpod
class DeleteAccount extends _$DeleteAccount {
  @override
  Future<void> build() async {}

  /// Soft-deletes the user profile and signs them out.
  /// Full auth-user deletion requires a server-side admin API call;
  /// add a Supabase Edge Function `delete-account` for that.
  Future<bool> deleteAccount() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await supabase
          .from('profiles')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      await supabase.auth.signOut();
      return true;
    } catch (e, st) {
      dev.log('DeleteAccount failed',
          name: 'Settings', error: e, stackTrace: st);
      return false;
    }
  }
}
