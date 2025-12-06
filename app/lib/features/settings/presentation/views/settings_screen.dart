import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../app/routes/app_router.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../../core/services/server/feature_flags_service.dart';
import '../widgets/about_card.dart';
import '../widgets/settings_category_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(featureFlagsProvider.notifier).refreshCapabilities();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'Settings',
          style: GoogleFonts.inter(color: AppColors.primary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Settings Grid - 2 columns
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              // Taller cards to accommodate content comfortably
              childAspectRatio: 0.85,
              children: [
                SettingsCategoryCard(
                  icon: LucideIcons.settings2,
                  title: 'App Settings',
                  subtitle: 'Haptics, streaming, data',
                  onTap: () {
                    hapticsHelper.triggerHaptics();
                    context.push(AppRoutes.settingsApp);
                  },
                  iconColor: AppColors.brand,
                ),
                SettingsCategoryCard(
                  icon: LucideIcons.image,
                  title: 'Media',
                  subtitle: 'Vision & documents',
                  badge: 'BETA',
                  onTap: () {
                    hapticsHelper.triggerHaptics();
                    context.push(AppRoutes.settingsMedia);
                  },
                  iconColor: AppColors.info,
                ),
                SettingsCategoryCard(
                  icon: LucideIcons.globe,
                  title: 'Web Search',
                  subtitle: 'Providers & modes',
                  badge: 'NEW',
                  onTap: () {
                    hapticsHelper.triggerHaptics();
                    context.push(AppRoutes.settingsWebSearch);
                  },
                  iconColor: AppColors.success,
                ),
                SettingsCategoryCard(
                  icon: LucideIcons.brain,
                  title: 'AI Settings',
                  subtitle: 'Style & prompts',
                  onTap: () {
                    hapticsHelper.triggerHaptics();
                    context.push(AppRoutes.settingsAI);
                  },
                  // Using a purple variant for AI that matches brandLight
                  iconColor: AppColors.brandLight,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // About Section
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'ABOUT PARALLAX CONNECT',
                      style: GoogleFonts.inter(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: ' - Learn more about the app and its philosophy',
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
            const AboutCard(),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'v1.0',
                style: GoogleFonts.inter(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
