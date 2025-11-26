import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/settings_storage.dart';

/// Helper class to trigger haptic feedback based on user settings
class HapticsHelper {
  final SettingsStorage _settingsStorage;

  // Throttle streaming haptics to avoid overwhelming the haptic engine
  DateTime? _lastStreamingHaptic;
  static const _streamingHapticInterval = Duration(milliseconds: 50);

  HapticsHelper(this._settingsStorage);

  /// Trigger haptic feedback based on current settings level
  /// - 'none': No haptic feedback
  /// - 'min': Light haptic feedback on button/icon clicks
  /// - 'max': min + streaming text haptics (typing feel)
  Future<void> triggerHaptics() async {
    final level = _settingsStorage.getHapticsLevel();

    switch (level) {
      case 'none':
        // No haptic feedback
        break;
      case 'min':
        // Light haptic feedback for button/icon clicks
        await HapticFeedback.lightImpact();
        break;
      case 'max':
        // Stronger haptic feedback for critical interactions
        await HapticFeedback.mediumImpact();
        break;
    }
  }

  /// Trigger haptic feedback for streaming text (typing feel)
  /// Only triggers when haptics level is 'max'
  /// Throttled to avoid overwhelming the haptic engine
  Future<void> triggerStreamingHaptic() async {
    final level = _settingsStorage.getHapticsLevel();

    // Only trigger for 'max' haptics level
    if (level != 'max') return;

    // Throttle haptics to avoid overwhelming the device
    final now = DateTime.now();
    if (_lastStreamingHaptic != null &&
        now.difference(_lastStreamingHaptic!) < _streamingHapticInterval) {
      return;
    }
    _lastStreamingHaptic = now;

    // Use selection click for a subtle typing feel
    await HapticFeedback.selectionClick();
  }

  /// Check if streaming haptics are enabled (max level)
  bool get isStreamingHapticsEnabled {
    return _settingsStorage.getHapticsLevel() == 'max';
  }
}

/// Provider for HapticsHelper
final hapticsHelperProvider = Provider<HapticsHelper>((ref) {
  final settingsStorage = ref.watch(settingsStorageProvider);
  return HapticsHelper(settingsStorage);
});
