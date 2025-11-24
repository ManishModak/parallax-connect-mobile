import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';

/// Provider for connectivity service
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Provider for current connectivity status stream
final connectivityStatusProvider = StreamProvider<ConnectivityResult>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Service to monitor network connectivity
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  static const _timeout = Duration(seconds: 5);

  /// Stream of connectivity changes
  Stream<ConnectivityResult> get onConnectivityChanged => _connectivity
      .onConnectivityChanged
      .map((List<ConnectivityResult> results) {
        final result = results.isNotEmpty
            ? results.first
            : ConnectivityResult.none;
        logger.network('Connectivity changed: $result');
        return result;
      });

  /// Check current connectivity status
  Future<bool> get isConnected async {
    try {
      final results = await _connectivity.checkConnectivity().timeout(_timeout);
      final connected =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      logger.network(
        'Connection status: ${connected ? 'connected' : 'disconnected'}',
      );
      return connected;
    } catch (e) {
      logger.e('Failed to check connectivity: $e');
      return false;
    }
  }

  /// Check if connected and has internet (for cloud mode)
  Future<bool> get hasInternetConnection async {
    try {
      final results = await _connectivity.checkConnectivity().timeout(_timeout);
      if (results.isEmpty || results.first == ConnectivityResult.none) {
        logger.network('No internet connection');
        return false;
      }

      // Check for mobile or wifi connection
      final hasConnection =
          results.first == ConnectivityResult.wifi ||
          results.first == ConnectivityResult.mobile;
      logger.network(
        'Internet connection: ${hasConnection ? 'available' : 'unavailable'}',
      );
      return hasConnection;
    } catch (e) {
      logger.e('Failed to check internet connection: $e');
      return false;
    }
  }

  /// Get connectivity result type
  Future<ConnectivityResult> get connectivityResult async {
    try {
      final results = await _connectivity.checkConnectivity().timeout(_timeout);
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      logger.network('Connectivity result: $result');
      return result;
    } catch (e) {
      logger.e('Failed to get connectivity result: $e');
      return ConnectivityResult.none;
    }
  }
}
