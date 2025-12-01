import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/logger.dart';

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
  static const _reachabilityHosts = ['google.com', 'cloudflare.com', '1.1.1.1'];

  /// Stream of connectivity changes
  Stream<ConnectivityResult> get onConnectivityChanged => _connectivity
      .onConnectivityChanged
      .map((List<ConnectivityResult> results) {
        return results.isNotEmpty ? results.first : ConnectivityResult.none;
      });

  /// Check if device has any network connection (wifi/mobile/ethernet)
  Future<bool> get isConnected async {
    try {
      final results = await _connectivity.checkConnectivity().timeout(_timeout);
      return results.isNotEmpty && results.first != ConnectivityResult.none;
    } catch (e) {
      Log.e('Connectivity check failed', e);
      return false;
    }
  }

  /// Check if device can actually reach the internet (not just connected to network)
  Future<bool> get hasInternetConnection async {
    try {
      final results = await _connectivity.checkConnectivity().timeout(_timeout);
      if (results.isEmpty || results.first == ConnectivityResult.none) {
        return false;
      }

      // Actually verify internet reachability by attempting DNS lookup
      return await _checkInternetReachability();
    } catch (e) {
      Log.e('Internet check failed', e);
      return false;
    }
  }

  /// Verify actual internet connectivity by attempting to reach known hosts
  Future<bool> _checkInternetReachability() async {
    for (final host in _reachabilityHosts) {
      try {
        final result = await InternetAddress.lookup(host).timeout(_timeout);
        if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // Try next host
        continue;
      }
    }
    Log.w('Internet reachability check failed for all hosts');
    return false;
  }

  Future<ConnectivityResult> get connectivityResult async {
    try {
      final results = await _connectivity.checkConnectivity().timeout(_timeout);
      return results.isNotEmpty ? results.first : ConnectivityResult.none;
    } catch (e) {
      Log.e('Connectivity result failed', e);
      return ConnectivityResult.none;
    }
  }
}
