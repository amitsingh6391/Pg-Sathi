import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity.
class ConnectivityService {
  ConnectivityService({required this.connectivity}) {
    _subscription = connectivity.onConnectivityChanged.listen((result) {
      _connectivityController.add(result);
    });
  }

  final Connectivity connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _connectivityController =
      StreamController<List<ConnectivityResult>>.broadcast();

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivityController.stream;

  /// Checks current connectivity status.
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return connectivity.checkConnectivity();
  }

  Future<bool> isConnected() async {
    final results = await checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  /// Checks if device has mobile data connection.
  Future<bool> hasMobileData() async {
    final results = await checkConnectivity();
    return results.contains(ConnectivityResult.mobile);
  }

  /// Checks if device has WiFi connection.
  Future<bool> hasWifi() async {
    final results = await checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Disposes resources.
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}
