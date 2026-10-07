import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class JumaaConnectivityService {
  JumaaConnectivityService._();

  static final JumaaConnectivityService instance =
      JumaaConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Stream<bool> get statusStream => _statusController.stream;

  Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    await _subscription?.cancel();

    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateStatus,
    );
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final online = results.any(
      (result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn ||
          result == ConnectivityResult.bluetooth ||
          result == ConnectivityResult.other,
    );

    if (_isOnline != online) {
      _isOnline = online;
      _statusController.add(_isOnline);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _statusController.close();
  }
}
