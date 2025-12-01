import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device requirements for different features
class FeatureRequirements {
  final String featureName;
  final int minRamMb;
  final int minAndroidSdk;
  final double minIosVersion;
  final String description;
  final List<String> warnings;

  const FeatureRequirements({
    required this.featureName,
    required this.minRamMb,
    this.minAndroidSdk = 21,
    this.minIosVersion = 12.0,
    required this.description,
    this.warnings = const [],
  });
}

/// Device info and capability checking
class DeviceInfo {
  final String deviceModel;
  final String osVersion;
  final int? sdkInt; // Android only
  final int? totalRamMb;
  final int? availableRamMb;
  final bool isLowEndDevice;
  final bool isPhysicalDevice;

  const DeviceInfo({
    required this.deviceModel,
    required this.osVersion,
    this.sdkInt,
    this.totalRamMb,
    this.availableRamMb,
    required this.isLowEndDevice,
    required this.isPhysicalDevice,
  });

  String get ramDisplay {
    if (totalRamMb == null) return 'Unknown';
    final gb = totalRamMb! / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  String get availableRamDisplay {
    if (availableRamMb == null) return 'Unknown';
    final gb = availableRamMb! / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }
}

/// Result of checking if device meets requirements
class RequirementCheckResult {
  final bool meetsRequirements;
  final List<String> issues;
  final List<String> warnings;
  final String recommendation;

  const RequirementCheckResult({
    required this.meetsRequirements,
    this.issues = const [],
    this.warnings = const [],
    this.recommendation = '',
  });
}

/// Service for checking device capabilities and requirements
class DeviceRequirementsService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  DeviceInfo? _cachedDeviceInfo;

  /// Feature requirements definitions
  static const Map<String, FeatureRequirements> featureRequirements = {
    'attachments': FeatureRequirements(
      featureName: 'Attachments',
      minRamMb: 2048, // 2GB
      description: 'Send images and documents in chat',
      warnings: ['May be slow on devices with less than 3GB RAM'],
    ),
    'edge_ocr': FeatureRequirements(
      featureName: 'Edge OCR',
      minRamMb: 2048, // 2GB
      minAndroidSdk: 24, // Android 7.0
      minIosVersion: 13.0,
      description: 'On-device text recognition using ML Kit',
      warnings: [
        'Requires 2GB+ RAM for smooth operation',
        'First use downloads ~20MB ML model',
      ],
    ),
    'document_processing': FeatureRequirements(
      featureName: 'Document Processing',
      minRamMb: 3072, // 3GB
      description: 'Process PDFs and large text files',
      warnings: [
        'Large PDFs (50+ pages) need 4GB+ RAM',
        'May cause slowdowns on low-end devices',
      ],
    ),
    'multimodal_vision': FeatureRequirements(
      featureName: 'Full Multimodal Vision',
      minRamMb: 4096, // 4GB
      minAndroidSdk: 26, // Android 8.0
      minIosVersion: 14.0,
      description: 'Server-side image processing',
      warnings: [
        'Requires stable network connection',
        'High-res images use significant bandwidth',
      ],
    ),
    'smart_context': FeatureRequirements(
      featureName: 'Smart Context',
      minRamMb: 2048, // 2GB
      description: 'Intelligent document chunking with RAG',
      warnings: ['Processing large documents may take time'],
    ),
  };

  /// Get device information
  Future<DeviceInfo> getDeviceInfo() async {
    if (_cachedDeviceInfo != null) return _cachedDeviceInfo!;

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final totalRam =
          androidInfo.systemFeatures.contains('android.hardware.ram.low')
          ? 2048 // Assume 2GB for low RAM devices
          : _estimateAndroidRam(androidInfo);

      _cachedDeviceInfo = DeviceInfo(
        deviceModel: '${androidInfo.manufacturer} ${androidInfo.model}',
        osVersion: 'Android ${androidInfo.version.release}',
        sdkInt: androidInfo.version.sdkInt,
        totalRamMb: totalRam,
        isLowEndDevice: androidInfo.isLowRamDevice,
        isPhysicalDevice: androidInfo.isPhysicalDevice,
      );
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      final estimatedRam = _estimateIosRam(iosInfo.utsname.machine);

      _cachedDeviceInfo = DeviceInfo(
        deviceModel: iosInfo.model,
        osVersion: 'iOS ${iosInfo.systemVersion}',
        totalRamMb: estimatedRam,
        isLowEndDevice: estimatedRam < 3072,
        isPhysicalDevice: iosInfo.isPhysicalDevice,
      );
    } else {
      _cachedDeviceInfo = const DeviceInfo(
        deviceModel: 'Unknown',
        osVersion: 'Unknown',
        isLowEndDevice: false,
        isPhysicalDevice: true,
      );
    }

    return _cachedDeviceInfo!;
  }

  /// Check if device meets requirements for a feature
  Future<RequirementCheckResult> checkRequirements(String featureKey) async {
    final requirements = featureRequirements[featureKey];
    if (requirements == null) {
      return const RequirementCheckResult(meetsRequirements: true);
    }

    final deviceInfo = await getDeviceInfo();
    final issues = <String>[];
    final warnings = <String>[...requirements.warnings];

    // Check RAM
    if (deviceInfo.totalRamMb != null &&
        deviceInfo.totalRamMb! < requirements.minRamMb) {
      issues.add(
        'Requires ${_formatRam(requirements.minRamMb)} RAM (device has ${deviceInfo.ramDisplay})',
      );
    }

    // Check Android SDK
    if (Platform.isAndroid && deviceInfo.sdkInt != null) {
      if (deviceInfo.sdkInt! < requirements.minAndroidSdk) {
        issues.add(
          'Requires Android ${_sdkToVersion(requirements.minAndroidSdk)}+ (device has ${deviceInfo.osVersion})',
        );
      }
    }

    // Check iOS version
    if (Platform.isIOS) {
      final currentVersion = _parseIosVersion(deviceInfo.osVersion);
      if (currentVersion < requirements.minIosVersion) {
        issues.add(
          'Requires iOS ${requirements.minIosVersion}+ (device has ${deviceInfo.osVersion})',
        );
      }
    }

    // Add low-end device warning
    if (deviceInfo.isLowEndDevice && issues.isEmpty) {
      warnings.insert(
        0,
        'Your device may experience slowdowns with this feature',
      );
    }

    // Generate recommendation
    String recommendation = '';
    if (issues.isNotEmpty) {
      recommendation =
          'This feature may not work properly on your device. Consider using a device with better specifications.';
    } else if (deviceInfo.isLowEndDevice) {
      recommendation =
          'Feature should work, but performance may be limited. Close other apps for best results.';
    }

    return RequirementCheckResult(
      meetsRequirements: issues.isEmpty,
      issues: issues,
      warnings: warnings,
      recommendation: recommendation,
    );
  }

  /// Get all feature requirements with device compatibility
  Future<Map<String, RequirementCheckResult>> checkAllFeatures() async {
    final results = <String, RequirementCheckResult>{};
    for (final key in featureRequirements.keys) {
      results[key] = await checkRequirements(key);
    }
    return results;
  }

  /// Estimate Android RAM based on device info
  int _estimateAndroidRam(AndroidDeviceInfo info) {
    // Use SDK version as rough estimate if actual RAM not available
    if (info.version.sdkInt >= 31) return 6144; // Android 12+
    if (info.version.sdkInt >= 29) return 4096; // Android 10+
    if (info.version.sdkInt >= 26) return 3072; // Android 8+
    return 2048;
  }

  /// Estimate iOS RAM based on device model
  int _estimateIosRam(String machine) {
    // iPhone models and their RAM
    if (machine.contains('iPhone14') ||
        machine.contains('iPhone15') ||
        machine.contains('iPhone16')) {
      return 6144; // 6GB
    }
    if (machine.contains('iPhone13') || machine.contains('iPhone12')) {
      return 4096; // 4GB
    }
    if (machine.contains('iPhone11') || machine.contains('iPhoneX')) {
      return 3072; // 3GB
    }
    // iPad Pro models
    if (machine.contains('iPad') && machine.contains('Pro')) {
      return 8192; // 8GB+
    }
    return 2048; // Default for older devices
  }

  String _formatRam(int mb) {
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(0)}GB';
    }
    return '${mb}MB';
  }

  String _sdkToVersion(int sdk) {
    const sdkVersions = {
      21: '5.0',
      22: '5.1',
      23: '6.0',
      24: '7.0',
      25: '7.1',
      26: '8.0',
      27: '8.1',
      28: '9.0',
      29: '10',
      30: '11',
      31: '12',
      32: '12L',
      33: '13',
      34: '14',
      35: '15',
    };
    return sdkVersions[sdk] ?? sdk.toString();
  }

  double _parseIosVersion(String osVersion) {
    final match = RegExp(r'iOS (\d+\.?\d*)').firstMatch(osVersion);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }
}

/// Provider for device requirements service
final deviceRequirementsServiceProvider = Provider<DeviceRequirementsService>((
  ref,
) {
  return DeviceRequirementsService();
});

/// Provider for device info
final deviceInfoProvider = FutureProvider<DeviceInfo>((ref) async {
  final service = ref.watch(deviceRequirementsServiceProvider);
  return service.getDeviceInfo();
});

/// Provider for all feature compatibility checks
final featureCompatibilityProvider =
    FutureProvider<Map<String, RequirementCheckResult>>((ref) async {
      final service = ref.watch(deviceRequirementsServiceProvider);
      return service.checkAllFeatures();
    });
