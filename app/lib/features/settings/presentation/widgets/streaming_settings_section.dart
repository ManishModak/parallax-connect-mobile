import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../app/constants/app_colors.dart';

class StreamingSettingsSection extends StatelessWidget {
  final bool isStreamingEnabled;
  final bool showThinking;
  final ValueChanged<bool> onStreamingChanged;
  final ValueChanged<bool> onShowThinkingChanged;
  final VoidCallback? onHapticFeedback;

  const StreamingSettingsSection({
    super.key,
    required this.isStreamingEnabled,
    required this.showThinking,
    required this.onStreamingChanged,
    required this.onShowThinkingChanged,
    this.onHapticFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Streaming toggle
        _buildToggleTile(
          icon: LucideIcons.radio,
          title: 'Streaming Responses',
          description: 'See responses as they\'re generated in real-time',
          value: isStreamingEnabled,
          onChanged: (val) {
            onHapticFeedback?.call();
            onStreamingChanged(val);
          },
        ),
        const SizedBox(height: 12),
        // Show thinking toggle (only enabled when streaming is on)
        AnimatedOpacity(
          opacity: isStreamingEnabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: _buildToggleTile(
            icon: LucideIcons.brain,
            title: 'Show Thinking Process',
            description: 'Display model\'s reasoning as it thinks',
            value: showThinking,
            onChanged: isStreamingEnabled
                ? (val) {
                    onHapticFeedback?.call();
                    onShowThinkingChanged(val);
                  }
                : null,
            infoNote: isStreamingEnabled
                ? 'Rolling display shows 5 lines at a time'
                : 'Enable streaming to use this feature',
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
    String? infoNote,
  }) {
    final isEnabled = onChanged != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? () => onChanged(!value) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (value && isEnabled)
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: (value && isEnabled)
                        ? AppColors.primary
                        : AppColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: isEnabled
                              ? AppColors.primary
                              : AppColors.secondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          color: AppColors.secondary,
                          fontSize: 13,
                        ),
                      ),
                      if (infoNote != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          infoNote,
                          style: GoogleFonts.inter(
                            color: AppColors.secondary.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                  activeColor: AppColors.primary,
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary;
                    }
                    return AppColors.secondary;
                  }),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary.withValues(alpha: 0.3);
                    }
                    return AppColors.secondary.withValues(alpha: 0.2);
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
