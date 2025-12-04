import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// ANSI color codes for terminal output
class LogColors {
  static const String reset = '\x1B[0m';
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String magenta = '\x1B[35m';
  static const String cyan = '\x1B[36m';
  static const String white = '\x1B[37m';
  static const String gray = '\x1B[90m';

  // Bright variants
  static const String brightRed = '\x1B[91m';
  static const String brightGreen = '\x1B[92m';
  static const String brightYellow = '\x1B[93m';
  static const String brightBlue = '\x1B[94m';
  static const String brightMagenta = '\x1B[95m';
  static const String brightCyan = '\x1B[96m';
}

/// Minimalist single-line printer - no boxes, no clutter
class MinimalPrinter extends LogPrinter {
  final bool colors;
  final bool printTime;

  MinimalPrinter({this.colors = true, this.printTime = true});

  String _getTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  String _getLevelTag(Level level) {
    switch (level) {
      case Level.trace:
        return colors ? '${LogColors.gray}[TRC]${LogColors.reset}' : '[TRC]';
      case Level.debug:
        return colors ? '${LogColors.cyan}[DBG]${LogColors.reset}' : '[DBG]';
      case Level.info:
        return colors
            ? '${LogColors.brightGreen}[INF]${LogColors.reset}'
            : '[INF]';
      case Level.warning:
        return colors
            ? '${LogColors.brightYellow}[WRN]${LogColors.reset}'
            : '[WRN]';
      case Level.error:
        return colors
            ? '${LogColors.brightRed}[ERR]${LogColors.reset}'
            : '[ERR]';
      case Level.fatal:
        return colors ? '${LogColors.red}[FTL]${LogColors.reset}' : '[FTL]';
      default:
        return '[LOG]';
    }
  }

  @override
  List<String> log(LogEvent event) {
    final lines = <String>[];
    final time = printTime
        ? '${LogColors.gray}${_getTime()}${LogColors.reset} '
        : '';
    final tag = _getLevelTag(event.level);
    final message = event.message;

    lines.add('$time$tag $message');

    // Add error and stack trace on separate lines if present
    if (event.error != null) {
      final errorColor = colors ? LogColors.red : '';
      final reset = colors ? LogColors.reset : '';
      lines.add('$time     $errorColor↳ Error: ${event.error}$reset');
    }

    if (event.stackTrace != null) {
      final stackColor = colors ? LogColors.gray : '';
      final reset = colors ? LogColors.reset : '';
      final stackLines = event.stackTrace.toString().split('\n').take(5);
      for (final line in stackLines) {
        if (line.trim().isNotEmpty) {
          lines.add('$time     $stackColor$line$reset');
        }
      }
    }

    return lines;
  }
}

/// Custom file output for logger
class FileOutput extends LogOutput {
  File? _file;
  IOSink? _sink;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  @override
  Future<void> init() async {
    super.init();
    await _initLogFile();
  }

  Future<void> _initLogFile() async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

      // Get application documents directory for cross-platform compatibility
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDir.path}/applogs');

      // Create logs directory if it doesn't exist
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Clean up old log files (keep only last 5)
      await _cleanupOldLogs(logDir);

      final logPath = '${logDir.path}/debug_$timestamp.txt';

      _file = File(logPath);
      _sink = _file!.openWrite(mode: FileMode.append);
      _sink!.writeln('=== Log started at ${DateTime.now()} ===\n');
      _initialized = true;

      debugPrint('📝 Logging to: ${_file!.absolute.path}');
    } catch (e) {
      debugPrint('Failed to initialize log file: $e');
    }
  }

  /// Clean up old log files, keeping only the most recent ones
  Future<void> _cleanupOldLogs(Directory logDir, {int keepCount = 5}) async {
    try {
      final files = await logDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();

      if (files.length <= keepCount) return;

      // Sort by modification time (oldest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return aStat.modified.compareTo(bStat.modified);
      });

      // Calculate total log size and delete based on size and age
      final toDelete = files.take(files.length - keepCount);
      int deletedCount = 0;
      int totalFreedSpace = 0;

      for (final file in toDelete) {
        final fileSize = await file.length();
        await file.delete();
        totalFreedSpace += fileSize;
        deletedCount++;
        debugPrint(
          '🗑️ Deleted old log: ${file.path} (${(fileSize / 1024).toStringAsFixed(1)} KB)',
        );
      }

      if (deletedCount > 0) {
        debugPrint(
          '📊 Log cleanup: Freed ${(totalFreedSpace / 1024).toStringAsFixed(1)} KB, deleted $deletedCount files',
        );
      }
    } catch (e) {
      debugPrint('Failed to cleanup old logs: $e');
    }
  }

  @override
  void output(OutputEvent event) {
    if (_sink != null) {
      for (var line in event.lines) {
        // Strip ANSI codes for file output
        final cleanLine = line.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
        _sink!.writeln(cleanLine);
      }
    }
  }

  @override
  Future<void> destroy() async {
    await _sink?.close();
    await super.destroy();
  }
}

/// Global logger instance
final logger = _createLogger();

Logger _createLogger() {
  if (kReleaseMode) {
    return Logger(
      level: Level.warning,
      printer: MinimalPrinter(colors: false, printTime: false),
      filter: ProductionFilter(),
    );
  }

  return Logger(
    level: Level.debug,
    printer: MinimalPrinter(colors: true, printTime: true),
    filter: DevelopmentFilter(),
    output: MultiOutput([ConsoleOutput(), FileOutput()]),
  );
}

/// Convenience logging functions with category prefixes
class Log {
  Log._();

  /// Debug log
  static void d(String message, [dynamic data]) {
    logger.d(data != null ? '$message: $data' : message);
  }

  /// Info log
  static void i(String message, [dynamic data]) {
    logger.i(data != null ? '$message: $data' : message);
  }

  /// Warning log
  static void w(String message, [dynamic data]) {
    logger.w(data != null ? '$message: $data' : message);
  }

  /// Error log
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Network request/response
  static void network(String message, [dynamic data]) {
    logger.i(
      '${LogColors.brightBlue}🌐 NET${LogColors.reset} $message${data != null ? ': $data' : ''}',
    );
  }

  /// Navigation events
  static void nav(String message, [dynamic data]) {
    logger.d(
      '${LogColors.magenta}🧭 NAV${LogColors.reset} $message${data != null ? ': $data' : ''}',
    );
  }

  /// Storage operations
  static void storage(String message, [dynamic data]) {
    logger.d(
      '${LogColors.green}💾 DB${LogColors.reset} $message${data != null ? ': $data' : ''}',
    );
  }

  /// API calls
  static void api(String method, String url, {int? status, dynamic body}) {
    final statusColor = status != null && status >= 200 && status < 300
        ? LogColors.brightGreen
        : LogColors.brightRed;
    final statusText = status != null
        ? ' $statusColor[$status]${LogColors.reset}'
        : '';
    logger.i(
      '${LogColors.brightCyan}📡 API${LogColors.reset} $method $url$statusText',
    );
    if (body != null) {
      logger.d('    ↳ $body');
    }
  }

  /// User action
  static void action(String message, [dynamic data]) {
    logger.d(
      '${LogColors.yellow}👆 ACT${LogColors.reset} $message${data != null ? ': $data' : ''}',
    );
  }
}
