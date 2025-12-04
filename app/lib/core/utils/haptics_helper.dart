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

/// Helper class to trigger haptic feedback based on user settings.
///
/// Provides contextual haptic feedback for different events:
/// - Button presses (light/medium impact)
/// - Streaming text (typing feel with throttling)
/// - State transitions (streaming start, thinking, completion)
/// - Success/warning feedback for user actions
class HapticsHelper {
  final HapticsSettings _settings;

  // Throttle streaming haptics to avoid overwhelming the haptic engine
  // Using 50ms for snappier, more responsive typing feel
  DateTime? _lastStreamingHaptic;
  static const _streamingHapticInterval = Duration(milliseconds: 50);

  // Track punctuation for adaptive haptics
  static final _punctuationPattern = RegExp(r'[.!?,:;\n]');

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
  Future<void> triggerStreamingHaptic({String? content}) async {
    final level = _settings.getHapticsLevel();

    if (level != 'max') return;

    final now = DateTime.now();

    // Use shorter throttle for punctuation to emphasize sentence endings
    final interval = (content != null && _punctuationPattern.hasMatch(content))
        ? const Duration(milliseconds: 30)
        : _streamingHapticInterval;

    if (_lastStreamingHaptic != null &&
        now.difference(_lastStreamingHaptic!) < interval) {
      return;
    }
    _lastStreamingHaptic = now;

    await HapticFeedback.selectionClick();
  }

  /// Trigger haptic when streaming starts
  /// Provides a distinct "start" feel to signal response began
  Future<void> triggerStreamingStart() async {
    final level = _settings.getHapticsLevel();
    if (level == 'none') return;

    await HapticFeedback.mediumImpact();
  }

  /// Trigger haptic when streaming completes
  /// Provides a satisfying "done" feel
  Future<void> triggerStreamingComplete() async {
    final level = _settings.getHapticsLevel();
    if (level == 'none') return;

    await HapticFeedback.heavyImpact();
  }

  /// Trigger subtle haptic for thinking/analyzing phase
  /// Soft feedback to indicate AI is processing
  Future<void> triggerThinkingPulse() async {
    final level = _settings.getHapticsLevel();
    if (level != 'max') return;

    await HapticFeedback.selectionClick();
  }

  /// Trigger success haptic for completed actions
  /// (copy, send, successful operations)
  Future<void> triggerSuccess() async {
    final level = _settings.getHapticsLevel();
    if (level == 'none') return;

    await HapticFeedback.heavyImpact();
  }

  /// Trigger warning haptic for errors or warnings
  Future<void> triggerWarning() async {
    final level = _settings.getHapticsLevel();
    if (level == 'none') return;

    // Use vibrate pattern for distinct warning feel
    await HapticFeedback.vibrate();
  }

  /// Check if streaming haptics are enabled (max level)
  bool get isStreamingHapticsEnabled {
    return _settings.getHapticsLevel() == 'max';
  }

  /// Check if any haptics are enabled
  bool get isHapticsEnabled {
    return _settings.getHapticsLevel() != 'none';
  }
}

/// Provider for HapticsHelper
final hapticsHelperProvider = Provider<HapticsHelper>((ref) {
  final settings = ref.watch(hapticsSettingsProvider);
  return HapticsHelper(settings);
});
