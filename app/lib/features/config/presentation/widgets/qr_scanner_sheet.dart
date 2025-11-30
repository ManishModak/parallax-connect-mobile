import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/utils/haptics_helper.dart';

class QrScannerSheet extends ConsumerStatefulWidget {
  const QrScannerSheet({super.key});

  @override
  ConsumerState<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends ConsumerState<QrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasDetected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final hapticsHelper = ref.read(hapticsHelperProvider);

    return SafeArea(
      child: SizedBox(
        height: height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Scan Server QR',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close scanner',
                    icon:
                        const Icon(LucideIcons.x, color: AppColors.primary),
                    onPressed: () {
                      hapticsHelper.triggerHaptics();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Align the QR code within the frame to capture the server URL.',
                style: GoogleFonts.inter(
                  color: AppColors.primary.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      if (_hasDetected) return;
                      for (final barcode in capture.barcodes) {
                        final rawValue = barcode.rawValue;
                        if (rawValue != null && rawValue.isNotEmpty) {
                          setState(() {
                            _hasDetected = true;
                          });
                          Navigator.of(context).pop(rawValue);
                          break;
                        }
                      }
                    },
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.7),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

