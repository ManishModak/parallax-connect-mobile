import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/constants/app_colors.dart';
import '../widgets/qr_scanner_sheet.dart';

class QrScannerHandler {
  static Future<String?> scanUrl(BuildContext context) async {
    try {
      final scannedValue = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        builder: (_) => const QrScannerSheet(),
      );

      if (scannedValue == null) return null;
      final trimmed = scannedValue.trim();
      if (trimmed.isEmpty) return null;
      return trimmed;
    } on PlatformException {
      rethrow;
    }
  }
}


