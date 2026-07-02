import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device currently has a network connection.
///
/// The app is fully playable offline, so this is used only to surface an
/// offline indicator and to gate any future features that need live access
/// (see `requireConnection` in `ui/offline_banner.dart`).
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _online = true;

  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  /// Whether a network connection is currently available.
  bool get online => _online;

  Future<void> _init() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (_) {
      // If the platform check fails, assume online rather than blocking use.
      _apply(const [ConnectivityResult.wifi]);
    }
    _subscription = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final online =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (online != _online) {
      _online = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
