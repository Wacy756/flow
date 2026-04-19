import 'dart:developer' as dev;

// ============================================================
// Push notification service — STUB (Firebase not yet configured)
//
// To enable push notifications:
//   1. Create a Firebase project at console.firebase.google.com
//   2. Add Android app (package: uk.co.flowsapp.flow_app)
//      → download google-services.json → place in android/app/
//   3. Add iOS app → download GoogleService-Info.plist → place in ios/Runner/
//   4. Run: flutterfire configure
//   5. Re-add to pubspec.yaml:
//        firebase_core: ^3.13.0
//        firebase_messaging: ^15.2.5
//        flutter_local_notifications: ^18.0.1
//   6. Restore full implementation from git history
// ============================================================

/// Holds a deep-link target that arrived while the app was cold-started.
/// Dashboards check and clear this in their [initState].
class PushDeepLink {
  PushDeepLink._();
  static String? incidentId;
  static String? tenancyId;
}

class PushService {
  PushService._();

  /// No-op until Firebase is configured. See file header for setup steps.
  static Future<void> init() async {
    dev.log(
      'PushService.init() skipped — Firebase not configured',
      name: 'PushService',
    );
  }

  /// No-op until Firebase is configured.
  static Future<void> removeToken() async {
    dev.log(
      'PushService.removeToken() skipped — Firebase not configured',
      name: 'PushService',
    );
  }
}
