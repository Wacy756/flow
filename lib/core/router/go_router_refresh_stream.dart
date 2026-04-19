import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] to a [ChangeNotifier] so go_router can listen for
/// auth state changes and re-evaluate its [redirect] callback automatically.
///
/// Usage:
///   GoRouter(refreshListenable: GoRouterRefreshStream(stream), ...)
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
