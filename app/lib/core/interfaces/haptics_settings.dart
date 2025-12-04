/// Interface for accessing haptics settings.
///
/// This abstraction allows core to depend on an interface rather than
/// the concrete SettingsStorage implementation in features layer.
abstract class HapticsSettings {
  /// Get the current haptics level.
  /// Returns: 'none', 'min', or 'max'
  String getHapticsLevel();
}
