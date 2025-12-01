import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/dio_provider.dart';
import '../storage/config_storage.dart';
import '../../utils/logger.dart';

/// Server capabilities returned from /info endpoint
class ServerCapabilities {
  final int vramGb;
  final bool visionSupported;
  final bool documentProcessing;
  final int maxContextWindow;
  final bool multimodalSupported;
  final DateTime? fetchedAt;

  const ServerCapabilities({
    this.vramGb = 0,
    this.visionSupported = false,
    this.documentProcessing = false,
    this.maxContextWindow = 4096,
    this.multimodalSupported = false,
    this.fetchedAt,
  });

  /// Default capabilities when server info is unavailable
  factory ServerCapabilities.defaults() => const ServerCapabilities();

  factory ServerCapabilities.fromJson(Map<String, dynamic> json) {
    final caps = json['capabilities'] as Map<String, dynamic>? ?? {};
    return ServerCapabilities(
      vramGb: caps['vram_gb'] as int? ?? 0,
      visionSupported: caps['vision_supported'] as bool? ?? false,
      documentProcessing: caps['document_processing'] as bool? ?? false,
      maxContextWindow: caps['max_context_window'] as int? ?? 4096,
      multimodalSupported: caps['multimodal_supported'] as bool? ?? false,
      fetchedAt: DateTime.now(),
    );
  }

  /// Check if capabilities have been fetched from server
  bool get isFetched => fetchedAt != null;

  /// Check if capabilities are stale (older than 5 minutes)
  bool get isStale {
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt!).inMinutes > 5;
  }

  ServerCapabilities copyWith({
    int? vramGb,
    bool? visionSupported,
    bool? documentProcessing,
    int? maxContextWindow,
    bool? multimodalSupported,
    DateTime? fetchedAt,
  }) {
    return ServerCapabilities(
      vramGb: vramGb ?? this.vramGb,
      visionSupported: visionSupported ?? this.visionSupported,
      documentProcessing: documentProcessing ?? this.documentProcessing,
      maxContextWindow: maxContextWindow ?? this.maxContextWindow,
      multimodalSupported: multimodalSupported ?? this.multimodalSupported,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

/// Service to fetch and cache server capabilities
class ServerCapabilitiesService {
  final Dio _dio;
  final ConfigStorage _configStorage;

  ServerCapabilitiesService(this._dio, this._configStorage);

  Map<String, String>? _buildPasswordHeader() {
    final password = _configStorage.getPassword();
    if (password == null || password.isEmpty) return null;
    return {'x-password': password};
  }

  /// Fetch capabilities from server /info endpoint
  Future<ServerCapabilities> fetchCapabilities() async {
    final baseUrl = _configStorage.getBaseUrl();
    if (baseUrl == null) {
      logger.w('No base URL configured, returning default capabilities');
      return ServerCapabilities.defaults();
    }

    try {
      final response = await _dio.get(
        '$baseUrl/info',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 5),
          headers: _buildPasswordHeader(),
        ),
      );

      if (response.statusCode == 200) {
        final caps = ServerCapabilities.fromJson(
          response.data as Map<String, dynamic>,
        );
        logger.i(
          'Server capabilities fetched: VRAM=${caps.vramGb}GB, '
          'vision=${caps.visionSupported}, multimodal=${caps.multimodalSupported}',
        );
        return caps;
      }
    } catch (e) {
      logger.e('Failed to fetch server capabilities', error: e);
    }

    return ServerCapabilities.defaults();
  }
}

final serverCapabilitiesServiceProvider = Provider<ServerCapabilitiesService>((
  ref,
) {
  final dio = ref.watch(dioProvider);
  final configStorage = ref.watch(configStorageProvider);
  return ServerCapabilitiesService(dio, configStorage);
});

/// Cached server capabilities state
class ServerCapabilitiesNotifier extends AsyncNotifier<ServerCapabilities> {
  @override
  Future<ServerCapabilities> build() async {
    // Start with defaults, will be refreshed when needed
    return ServerCapabilities.defaults();
  }

  /// Refresh capabilities from server
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(serverCapabilitiesServiceProvider);
      final caps = await service.fetchCapabilities();
      state = AsyncValue.data(caps);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Get current capabilities (fetches if not yet loaded or stale)
  Future<ServerCapabilities> getCapabilities() async {
    final current = state.value;
    if (current == null || current.isStale) {
      await refresh();
    }
    return state.value ?? ServerCapabilities.defaults();
  }
}

final serverCapabilitiesProvider =
    AsyncNotifierProvider<ServerCapabilitiesNotifier, ServerCapabilities>(() {
      return ServerCapabilitiesNotifier();
    });
