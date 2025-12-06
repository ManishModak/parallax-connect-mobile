import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/haptics_helper.dart';
import '../../../../../app/constants/app_colors.dart';
import '../menus/web_search_menu.dart';

class WebSearchMenuHandler {
  static OverlayEntry createOverlayEntry({
    required BuildContext context,
    required WidgetRef ref,
    required LayerLink layerLink,
    required Function(String mode) onModeSelected,
    required VoidCallback onRemoveOverlay,
  }) {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -300),
          child: TapRegion(
            groupId: 'menu_group',
            child: WebSearchMenu(
              onDeep: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                onRemoveOverlay();
                onModeSelected('deep');
              },
              onNormal: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                onRemoveOverlay();
                onModeSelected('normal');
              },
              onDeeper: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                onRemoveOverlay();
                onModeSelected('deeper');
              },
              onOff: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                onRemoveOverlay();
                onModeSelected('off');
              },
            ),
          ),
        ),
      ),
    );
  }
}

