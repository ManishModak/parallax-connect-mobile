import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/logger.dart';

/// Custom exception for file service errors
class FileServiceException implements Exception {
  final String message;
  final FileServiceError errorType;

  FileServiceException(this.message, this.errorType);

  @override
  String toString() => 'FileServiceException: $message';
}

/// File service error types
enum FileServiceError {
  permissionDenied,
  fileTooLarge,
  invalidFileType,
  cancelled,
  unknown,
}

final fileServiceProvider = Provider<FileService>((ref) => FileService());

/// Service for file operations
class FileService {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  /// Pick an image file
  Future<File?> pickImage() async {
    try {
      // Check permission status first before requesting
      var status = await Permission.photos.status;
      
      if (status.isPermanentlyDenied) {
        Log.w('Photo permission permanently denied');
        throw FileServiceException(
          'Permission to access photos is permanently denied. Please enable it in settings.',
          FileServiceError.permissionDenied,
        );
      }

      if (!status.isGranted) {
        status = await Permission.photos.request();
        
        if (status.isDenied) {
          Log.w('Photo permission denied');
          throw FileServiceException(
            'Permission to access photos was denied',
            FileServiceError.permissionDenied,
          );
        }
      }

      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null) {
        return null; // User cancelled
      }

      if (result.files.single.path == null) {
        Log.e('File path is null');
        throw FileServiceException(
          'Failed to get file path',
          FileServiceError.unknown,
        );
      }

      final file = File(result.files.single.path!);

      // Validate file size
      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        Log.w('File too large: $fileSize bytes');
        throw FileServiceException(
          'File is too large. Maximum size is ${maxFileSizeBytes ~/ (1024 * 1024)} MB',
          FileServiceError.fileTooLarge,
        );
      }

      Log.d('Image picked: ${file.path}');
      return file;
    } on FileServiceException {
      rethrow;
    } catch (e) {
      Log.e('Failed to pick image', e);
      throw FileServiceException(
        'Failed to pick image: $e',
        FileServiceError.unknown,
      );
    }
  }

  /// Pick any file
  Future<File?> pickFile({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null) return null;

      if (result.files.single.path == null) {
        Log.e('File path is null');
        throw FileServiceException(
          'Failed to get file path',
          FileServiceError.unknown,
        );
      }

      final file = File(result.files.single.path!);
      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        Log.w('File too large: $fileSize bytes');
        throw FileServiceException(
          'File is too large. Maximum size is ${maxFileSizeBytes ~/ (1024 * 1024)} MB',
          FileServiceError.fileTooLarge,
        );
      }

      Log.d('File picked: ${file.path}');
      return file;
    } on FileServiceException {
      rethrow;
    } catch (e) {
      Log.e('Failed to pick file', e);
      throw FileServiceException(
        'Failed to pick file: $e',
        FileServiceError.unknown,
      );
    }
  }
}
