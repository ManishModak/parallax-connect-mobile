import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../sections/media_documents_section.dart';
import '../widgets/device_requirements_card.dart';

/// Media Settings page containing attachments, vision, and document processing
class MediaSettingsPage extends ConsumerWidget {
  const MediaSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticsHelper = ref.read(hapticsHelperProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.secondary),
          onPressed: () {
            hapticsHelper.triggerHaptics();
            context.pop();
          },
        ),
        title: Text(
          'Media & Documents',
          style: GoogleFonts.inter(color: AppColors.primary),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MediaDocumentsSection(hapticsHelper: hapticsHelper),
          const SizedBox(height: 32),

          // Device Compatibility Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'DEVICE COMPATIBILITY',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' - Check if your device meets the requirements for advanced features',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const DeviceRequirementsCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
