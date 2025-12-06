import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../sections/web_search_section.dart';

/// Web Search Settings page
class WebSearchSettingsPage extends ConsumerWidget {
  const WebSearchSettingsPage({super.key});

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
          'Web Search',
          style: GoogleFonts.inter(color: AppColors.primary),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WebSearchSection(hapticsHelper: hapticsHelper),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
