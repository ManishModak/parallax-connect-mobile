import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../network/dio_provider.dart';
import '../storage/config_storage.dart';
import '../../utils/logger.dart';

/// Service to upload local logs to the server
class LogUploadService {
  final Dio _dio;
  final ConfigStorage _configStorage;

  LogUploadService(this._dio, this._configStorage);

  /// Get the local logs directory
  Future<Directory> get _logsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/applogs');
  }

  /// Get device identifier for log tagging
  Future<(String id, String name)> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return (info.id, '${info.brand} ${info.model}');
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return (info.identifierForVendor ?? 'unknown', info.name);
      }
    } catch (e) {
      Log.e('Failed to get device info', e);
    }
    return ('unknown', 'Unknown Device');
  }

  /// Read all local log files and combine their content
  Future<String?> _readLocalLogs() async {
    try {
      final logsDir = await _logsDir;
      if (!await logsDir.exists()) {
        return null;
      }

      final logFiles = await logsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();

      if (logFiles.isEmpty) {
        return null;
      }

      // Sort by modification time (newest first)
      logFiles.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      final buffer = StringBuffer();
      for (final file in logFiles) {
        buffer.writeln('=== ${file.path.split('/').last} ===');
        buffer.writeln(await file.readAsString());
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      Log.e('Failed to read local logs', e);
      return null;
    }
  }

  /// Upload logs to the server
  /// Returns (success, message)
  Future<(bool, String)> uploadLogs() async {
    final baseUrl = _configStorage.getBaseUrl();
    if (baseUrl == null) {
      return (false, 'No server configured');
    }

    final logs = await _readLocalLogs();
    if (logs == null || logs.isEmpty) {
      return (false, 'No logs to upload');
    }

    final (deviceId, deviceName) = await _getDeviceInfo();

    try {
      Log.i('Uploading logs to server...');

      final response = await _dio.post(
        '$baseUrl/logs/upload',
        data: {'device_id': deviceId, 'device_name': deviceName, 'logs': logs},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final filename = data['filename'] ?? 'unknown';
        Log.i('Logs uploaded successfully: $filename');
        return (true, 'Logs sent successfully');
      } else {
        return (false, 'Server returned ${response.statusCode}');
      }
    } on DioException catch (e) {
      Log.e('Failed to upload logs', e);
      return (false, e.message ?? 'Upload failed');
    } catch (e) {
      Log.e('Failed to upload logs', e);
      return (false, 'Upload failed: $e');
    }
  }

  /// Check if there are logs available to upload
  Future<bool> hasLogsToUpload() async {
    if (kReleaseMode) return false;

    final logsDir = await _logsDir;
    if (!await logsDir.exists()) return false;

    final files = await logsDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.txt'))
        .length;
    return files > 0;
  }
}

final logUploadServiceProvider = Provider<LogUploadService>((ref) {
  final dio = ref.watch(dioProvider);
  final configStorage = ref.watch(configStorageProvider);
  return LogUploadService(dio, configStorage);
});
