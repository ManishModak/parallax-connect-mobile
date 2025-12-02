import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../view_models/settings_controller.dart';
import '../widgets/expandable_feature_tile.dart';
import '../widgets/radio_option.dart';
import '../widgets/section_header.dart';

/// Web Search settings section
class WebSearchSection extends ConsumerWidget {
  final HapticsHelper hapticsHelper;

  const WebSearchSection({super.key, required this.hapticsHelper});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Web Search'),
        const SizedBox(height: 20),
        ExpandableFeatureTile(
          icon: LucideIcons.globe,
          title: 'Web Search',
          badgeText: 'NEW',
          description: 'Allow the AI to search the web for real-time info',
          isEnabled: state.isWebSearchEnabled,
          onToggle: (val) async {
            hapticsHelper.triggerHaptics();
            await controller.setWebSearchEnabled(val);
          },
          details: [
            'Fetches real-time information from the web',
            'Results are injected into the context window',
            'DuckDuckGo is free and unlimited (Default)',
            'Brave Search requires a free API key but is more robust',
          ],
        ),
        if (state.isWebSearchEnabled) ...[
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                // Smart Search Toggle
                SwitchListTile(
                  value: state.isSmartSearchEnabled,
                  onChanged: (val) {
                    hapticsHelper.triggerHaptics();
                    controller.setSmartSearchEnabled(val);
                  },
                  title: Text(
                    'Smart Search',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Intelligently decide when to search',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: AppColors.accent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                if (state.isSmartSearchEnabled) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Execution Mode',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RadioOption(
                          title: 'On Device (Mobile)',
                          description: 'Fastest. Logic runs locally.',
                          value: 'mobile',
                          groupValue: state.webSearchExecutionMode,
                          onChanged: (val) {
                            hapticsHelper.triggerHaptics();
                            controller.setWebSearchExecutionMode(val!);
                          },
                        ),
                        const SizedBox(height: 8),
                        RadioOption(
                          title: 'Middleware (Server)',
                          description: 'More powerful. Runs on server.',
                          value: 'middleware',
                          groupValue: state.webSearchExecutionMode,
                          onChanged: (val) {
                            hapticsHelper.triggerHaptics();
                            controller.setWebSearchExecutionMode(val!);
                          },
                        ),
                        const SizedBox(height: 8),
                        RadioOption(
                          title: 'Parallax (Model) (Not supported yet)',
                          description: 'Model decides. Most flexible.',
                          value: 'parallax',
                          groupValue: state.webSearchExecutionMode,
                          isDisabled: true,
                          onChanged: null,
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 1, indent: 16, endIndent: 16),

                // Existing Provider Options
                RadioOption(
                  title: 'DuckDuckGo (Recommended)',
                  description: 'Free, unlimited, privacy-focused scraping.',
                  value: 'duckduckgo',
                  groupValue: state.webSearchProvider,
                  onChanged: (val) {
                    hapticsHelper.triggerHaptics();
                    controller.setWebSearchProvider(val!);
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioOption(
                  title: 'Brave Search API',
                  description: 'Official API. High quality, requires key.',
                  techNote: 'Free tier: 2,000 queries/month',
                  value: 'brave',
                  groupValue: state.webSearchProvider,
                  onChanged: (val) {
                    hapticsHelper.triggerHaptics();
                    controller.setWebSearchProvider(val!);
                  },
                ),
                if (state.webSearchProvider == 'brave') ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Brave Search API Key',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller:
                              TextEditingController(
                                  text: state.braveSearchApiKey,
                                )
                                ..selection = TextSelection.fromPosition(
                                  TextPosition(
                                    offset:
                                        state.braveSearchApiKey?.length ?? 0,
                                  ),
                                ),
                          onChanged: (val) {
                            controller.setBraveSearchApiKey(val);
                          },
                          style: GoogleFonts.inter(color: AppColors.primary),
                          decoration: InputDecoration(
                            hintText: 'Enter your API key',
                            hintStyle: GoogleFonts.inter(
                              color: AppColors.secondary.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get a free key at api.search.brave.com',
                          style: GoogleFonts.inter(
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Search Depth removed (moved to Chat Input)
              ],
            ),
          ),
        ],
      ],
    );
  }
}
