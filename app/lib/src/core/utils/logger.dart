import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Global logger instance with environment-based configuration
final logger = _createLogger();

Logger _createLogger() {
  // In release mode, use minimal logging
  if (kReleaseMode) {
    return Logger(
      level: Level.warning, // Only log warnings and errors in production
      printer: SimplePrinter(),
      filter: ProductionFilter(),
    );
  }

  // In debug/profile mode, use detailed logging
  return Logger(
    level: Level.debug,
    printer: PrettyPrinter(
      methodCount: 0, // No stack trace for regular logs
      errorMethodCount: 5, // Stack trace for errors
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: true, // Show timestamps in debug mode
      excludeBox: {Level.debug: false, Level.trace: false},
    ),
    filter: DevelopmentFilter(),
  );
}

/// Custom log methods for convenience
extension LoggerExtension on Logger {
  /// Log network request
  void network(String message, [dynamic data]) {
    d(data != null ? '🌐 $message: $data' : '🌐 $message');
  }

  /// Log navigation
  void navigation(String message, [dynamic data]) {
    d(data != null ? '🧭 $message: $data' : '🧭 $message');
  }

  /// Log storage operation
  void storage(String message, [dynamic data]) {
    d(data != null ? '💾 $message: $data' : '💾 $message');
  }

  /// Log API response
  void api(String message, [dynamic data]) {
    d(data != null ? '📡 $message: $data' : '📡 $message');
  }
}
