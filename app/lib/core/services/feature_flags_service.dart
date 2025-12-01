import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../global/providers.dart';
import 'server_capabilities_service.dart';

/// Reasons why a feature might be disabled
enum FeatureDisabledReason {
  notFetched('Server capabilities not yet loaded'),
  insufficientVram('Requires 16GB+ VRAM on server'),
  visionNotSupported('Server-side vision not supported by Parallax'),
  documentProcessingNotSupported('Document processing not supported'),
  userDisabled('Disabled by user'),
  serverUnavailable('Cannot connect to server');

  final String message;
  const FeatureDisabledReason(this.message);
}

/// NOTE ON PARALLAX CAPABILITIES:
/// - Parallax does NOT support server-side vision/multimodal processing
/// - Images/documents are processed CLIENT-SIDE via:
///   * Edge OCR (Google ML Kit) - extracts text from images locally
///   * Smart Context - chunks documents before sending to server
/// - The server only receives TEXT, not raw images/documents
/// - "Attachments" feature enables local processing + sending extracted text

/// Feature availability status
class FeatureStatus {
  final bool isAvailable;
  final bool isEnabled;
  final FeatureDisabledReason? disabledReason;
  final String? customMessage;

  const FeatureStatus({
    required this.isAvailable,
    required this.isEnabled,
    this.disabledReason,
    this.customMessage,
  });

  /// Feature is both available and enabled
  bool get canUse => isAvailable && isEnabled;

  /// Get user-friendly message for why feature is disabled
  String get disabledMessage {
    if (canUse) return '';
    if (customMessage != null) return customMessage!;
    if (!isAvailable) {
      return disabledReason?.message ?? 'Feature not available';
    }
    return 'Feature disabled in settings';
  }

  factory FeatureStatus.available({bool enabled = true}) =>
      FeatureStatus(isAvailable: true, isEnabled: enabled);

  factory FeatureStatus.unavailable(
    FeatureDisabledReason reason, {
    String? message,
  }) => FeatureStatus(
    isAvailable: false,
    isEnabled: false,
    disabledReason: reason,
    customMessage: message,
  );
}

/// All feature flags for the app
class FeatureFlags {
  final FeatureStatus multimodalVision;
  final FeatureStatus attachments;
  final FeatureStatus documentProcessing;
  final int maxContextTokens;
  final bool capabilitiesFetched;

  const FeatureFlags({
    required this.multimodalVision,
    required this.attachments,
    required this.documentProcessing,
    required this.maxContextTokens,
    required this.capabilitiesFetched,
  });

  /// Default flags when nothing is loaded yet
  factory FeatureFlags.defaults() => FeatureFlags(
    multimodalVision: FeatureStatus.unavailable(
      FeatureDisabledReason.notFetched,
    ),
    attachments: FeatureStatus.unavailable(FeatureDisabledReason.notFetched),
    documentProcessing: FeatureStatus.unavailable(
      FeatureDisabledReason.notFetched,
    ),
    maxContextTokens: 4096,
    capabilitiesFetched: false,
  );
}

/// Storage keys for user feature preferences
class _FeaturePrefsKeys {
  static const multimodalEnabled = 'feature_multimodal_enabled';
  static const attachmentsEnabled = 'feature_attachments_enabled';
  static const documentProcessingEnabled = 'feature_doc_processing_enabled';
}

/// Notifier that combines server capabilities with user preferences
class FeatureFlagsNotifier extends Notifier<FeatureFlags> {
  @override
  FeatureFlags build() {
    // Listen to server capabilities changes
    ref.listen(serverCapabilitiesProvider, (_, next) {
      next.whenData((caps) => _updateFlags(caps));
    });

    return FeatureFlags.defaults();
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  /// Update flags based on server capabilities
  ///
  /// IMPORTANT: Parallax does NOT support server-side vision/multimodal.
  /// - Attachments: Always available (processed locally via Edge OCR)
  /// - Multimodal: NOT available (Parallax executor doesn't process images)
  /// - Document Processing: Always available (done locally via Smart Context)
  void _updateFlags(ServerCapabilities caps) {
    // Get user preferences (default to false for safety)
    final attachmentsUserEnabled =
        _prefs.getBool(_FeaturePrefsKeys.attachmentsEnabled) ?? false;
    final docProcessingUserEnabled =
        _prefs.getBool(_FeaturePrefsKeys.documentProcessingEnabled) ?? false;

    state = FeatureFlags(
      // Multimodal: NOT available (Parallax limitation)
      multimodalVision: FeatureStatus.unavailable(
        FeatureDisabledReason.visionNotSupported,
        message:
            'Parallax does not support server-side image processing. Use Edge OCR instead.',
      ),
      // Attachments: Available (processed locally via Edge OCR)
      attachments: _buildFeatureStatus(
        available: true, // Always available - processed on device
        userEnabled: attachmentsUserEnabled,
        unavailableReason: !caps.isFetched
            ? FeatureDisabledReason.notFetched
            : null,
      ),
      // Document Processing: Available (done locally via Smart Context)
      documentProcessing: _buildFeatureStatus(
        available: true, // Always available - processed on device
        userEnabled: docProcessingUserEnabled,
        unavailableReason: !caps.isFetched
            ? FeatureDisabledReason.notFetched
            : null,
      ),
      maxContextTokens: caps.maxContextWindow,
      capabilitiesFetched: caps.isFetched,
    );
  }

  FeatureStatus _buildFeatureStatus({
    required bool available,
    required bool userEnabled,
    FeatureDisabledReason? unavailableReason,
  }) {
    if (!available) {
      return FeatureStatus.unavailable(
        unavailableReason ?? FeatureDisabledReason.serverUnavailable,
      );
    }
    return FeatureStatus.available(enabled: userEnabled);
  }

  /// Enable/disable multimodal vision feature
  Future<void> setMultimodalEnabled(bool enabled) async {
    await _prefs.setBool(_FeaturePrefsKeys.multimodalEnabled, enabled);
    _refreshFromCurrentCaps();
  }

  /// Enable/disable attachments feature
  Future<void> setAttachmentsEnabled(bool enabled) async {
    await _prefs.setBool(_FeaturePrefsKeys.attachmentsEnabled, enabled);
    _refreshFromCurrentCaps();
  }

  /// Enable/disable document processing feature
  Future<void> setDocumentProcessingEnabled(bool enabled) async {
    await _prefs.setBool(_FeaturePrefsKeys.documentProcessingEnabled, enabled);
    _refreshFromCurrentCaps();
  }

  void _refreshFromCurrentCaps() {
    final caps = ref.read(serverCapabilitiesProvider).value;
    if (caps != null) {
      _updateFlags(caps);
    }
  }

  /// Refresh capabilities from server
  Future<void> refreshCapabilities() async {
    await ref.read(serverCapabilitiesProvider.notifier).refresh();
  }
}

final featureFlagsProvider =
    NotifierProvider<FeatureFlagsNotifier, FeatureFlags>(() {
      return FeatureFlagsNotifier();
    });
