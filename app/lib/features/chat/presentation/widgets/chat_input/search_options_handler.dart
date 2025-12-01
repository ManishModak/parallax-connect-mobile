import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/haptics_helper.dart';
import '../../../../settings/presentation/view_models/settings_controller.dart';
import '../search_options_menu.dart';

/// Helper class for creating search options overlay entries
class SearchOptionsHandler {
  /// Creates an overlay entry for the search options menu
  static OverlayEntry createOverlayEntry({
    required BuildContext context,
    required WidgetRef ref,
    required LayerLink layerLink,
    required VoidCallback onRemoveOverlay,
  }) {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -140),
          child: TapRegion(
            groupId: 'search_options_menu',
            onTapOutside: (_) => onRemoveOverlay(),
            child: SearchOptionsMenu(
              onDeepSearchToggle: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                final controller = ref.read(
                  settingsControllerProvider.notifier,
                );
                final currentDepth = ref
                    .read(settingsControllerProvider)
                    .webSearchDepth;

                if (currentDepth == 'deep') {
                  controller.setWebSearchDepth('normal');
                } else {
                  controller.setWebSearchDepth('deep');
                }
              },
              onDeeperSearchToggle: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                final controller = ref.read(
                  settingsControllerProvider.notifier,
                );
                final currentDepth = ref
                    .read(settingsControllerProvider)
                    .webSearchDepth;

                if (currentDepth == 'deeper') {
                  controller.setWebSearchDepth('normal');
                } else {
                  controller.setWebSearchDepth('deeper');
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

