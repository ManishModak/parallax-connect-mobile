import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/haptics_settings.dart';

/// Provider that must be overridden at app startup with a concrete
/// HapticsSettings implementation (e.g., SettingsStorage).
final hapticsSettingsProvider = Provider<HapticsSettings>((ref) {
  throw UnimplementedError(
    'hapticsSettingsProvider must be overridden in ProviderScope',
  );
});

/// Helper class to trigger haptic feedback based on user settings
class HapticsHelper {
  final HapticsSettings _settings;

  // Throttle streaming haptics to avoid overwhelming the haptic engine
  DateTime? _lastStreamingHaptic;
  static const _streamingHapticInterval = Duration(milliseconds: 80);

  HapticsHelper(this._settings);

  /// Trigger haptic feedback based on current settings level
  /// - 'none': No haptic feedback
  /// - 'min': Light haptic feedback on button/icon clicks
  /// - 'max': min + streaming text haptics (typing feel)
  Future<void> triggerHaptics() async {
    final level = _settings.getHapticsLevel();

    switch (level) {
      case 'none':
        break;
      case 'min':
        await HapticFeedback.lightImpact();
        break;
      case 'max':
        await HapticFeedback.mediumImpact();
        break;
    }
  }

  /// Trigger haptic feedback for streaming text (typing feel)
  /// Only triggers when haptics level is 'max'
  /// Throttled to avoid overwhelming the haptic engine
  Future<void> triggerStreamingHaptic() async {
    final level = _settings.getHapticsLevel();

    if (level != 'max') return;

    final now = DateTime.now();
    if (_lastStreamingHaptic != null &&
        now.difference(_lastStreamingHaptic!) < _streamingHapticInterval) {
      return;
    }
    _lastStreamingHaptic = now;

    await HapticFeedback.selectionClick();
  }

  /// Check if streaming haptics are enabled (max level)
  bool get isStreamingHapticsEnabled {
    return _settings.getHapticsLevel() == 'max';
  }
}

/// Provider for HapticsHelper
final hapticsHelperProvider = Provider<HapticsHelper>((ref) {
  final settings = ref.watch(hapticsSettingsProvider);
  return HapticsHelper(settings);
});
