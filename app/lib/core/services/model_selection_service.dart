import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants/app_constants.dart';
import '../../global/providers.dart';
import '../network/dio_provider.dart';
import '../storage/config_storage.dart';
import '../utils/logger.dart';

/// Model info from server
/// Parallax models have: name, vram_gb
/// Server normalizes to: id, name, context_length, vram_gb
class ModelInfo {
  final String id;
  final String name;
  final int contextLength;
  final int vramGb;

  const ModelInfo({
    required this.id,
    required this.name,
    this.contextLength = 32768,
    this.vramGb = 0,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Unknown Model',
      contextLength: json['context_length'] as int? ?? 32768,
      vramGb: json['vram_gb'] as int? ?? 0,
    );
  }
}

/// State for model selection
///
/// IMPORTANT: Parallax runs ONE model at a time. The 'activeModelId' is the
/// model currently running on the cluster. Selecting a different model in the
/// UI does NOT change the active model - that requires reinitializing the
/// scheduler via the Parallax Web UI.
class ModelSelectionState {
  final List<ModelInfo> availableModels;
  final String? activeModelId; // Currently running model on Parallax
  final String? selectedModelId; // User's selection (for display purposes)
  final bool isLoading;
  final String? error;

  const ModelSelectionState({
    this.availableModels = const [],
    this.activeModelId,
    this.selectedModelId,
    this.isLoading = false,
    this.error,
  });

  /// The active model running on Parallax (what's actually being used)
  ModelInfo? get activeModel {
    if (activeModelId == null) return null;
    return availableModels.cast<ModelInfo?>().firstWhere(
          (m) => m?.id == activeModelId,
          orElse: () => null,
        );
  }

  /// Whether the scheduler has been initialized with a model
  bool get hasActiveModel => activeModelId != null;

  ModelSelectionState copyWith({
    List<ModelInfo>? availableModels,
    String? activeModelId,
    String? selectedModelId,
    bool? isLoading,
    String? error,
  }) {
    return ModelSelectionState(
      availableModels: availableModels ?? this.availableModels,
      activeModelId: activeModelId ?? this.activeModelId,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Service to fetch and manage model selection
class ModelSelectionNotifier extends Notifier<ModelSelectionState> {
  @override
  ModelSelectionState build() {
    _loadSavedModel();
    return const ModelSelectionState();
  }

  void _loadSavedModel() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedModel = prefs.getString(StorageKeys.selectedModel);
    if (savedModel != null) {
      state = state.copyWith(selectedModelId: savedModel);
    }
  }

  Map<String, String>? _buildPasswordHeader() {
    final configStorage = ref.read(configStorageProvider);
    final password = configStorage.getPassword();
    if (password == null || password.isEmpty) return null;
    return {'x-password': password};
  }

  /// Fetch available models from server
  Future<void> fetchModels() async {
    final configStorage = ref.read(configStorageProvider);
    final baseUrl = configStorage.getBaseUrl();
    if (baseUrl == null) {
      state = state.copyWith(error: 'No server configured');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '$baseUrl/models',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          headers: _buildPasswordHeader(),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final modelsList = (data['models'] as List<dynamic>?) ?? [];
        final activeModel = data['active'] as String?; // Currently running
        final defaultModel = data['default'] as String?;

        final models = modelsList
            .map((m) => ModelInfo.fromJson(m as Map<String, dynamic>))
            .toList();

        // Selected model defaults to active model
        String? selectedId = activeModel ?? defaultModel;

        state = state.copyWith(
          availableModels: models,
          activeModelId: activeModel,
          selectedModelId: selectedId,
          isLoading: false,
        );

        logger.i(
          'Fetched ${models.length} models, active: $activeModel',
        );
      }
    } catch (e) {
      logger.e('Failed to fetch models', error: e);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch models',
      );
    }
  }

  /// Select a model
  Future<void> selectModel(String modelId) async {
    state = state.copyWith(selectedModelId: modelId);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(StorageKeys.selectedModel, modelId);
    logger.i('Selected model: $modelId');
  }
}

final modelSelectionProvider =
    NotifierProvider<ModelSelectionNotifier, ModelSelectionState>(() {
  return ModelSelectionNotifier();
});
