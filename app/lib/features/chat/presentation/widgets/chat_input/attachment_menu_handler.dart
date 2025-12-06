import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/haptics_helper.dart';
import '../menus/attachment_menu.dart';

/// Helper class for creating attachment menu overlay entries
class AttachmentMenuHandler {
  /// Creates an overlay entry for the attachment menu
  static OverlayEntry createOverlayEntry({
    required BuildContext context,
    required WidgetRef ref,
    required LayerLink layerLink,
    required Future<String?> Function() onCameraTap,
    required Future<List<String>> Function() onGalleryTap,
    required Future<List<String>> Function() onFileTap,
    required VoidCallback onRemoveOverlay,
    required Function(String?) onAttachmentSelected,
    required Function(List<String>) onAttachmentsSelected,
  }) {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -220),
          child: TapRegion(
            groupId: 'menu_group',
            child: AttachmentMenu(
              onCameraTap: () async {
                ref.read(hapticsHelperProvider).triggerHaptics();
                onRemoveOverlay();
                final path = await onCameraTap();
                if (path != null) {
                  onAttachmentSelected(path);
                }
              },
              onGalleryTap: () async {
                ref.read(hapticsHelperProvider).triggerHaptics();
                onRemoveOverlay();
                final paths = await onGalleryTap();
                if (paths.isNotEmpty) {
                  onAttachmentsSelected(paths);
                }
              },
              onFileTap: () async {
                ref.read(hapticsHelperProvider).triggerHaptics();
                onRemoveOverlay();
                final paths = await onFileTap();
                if (paths.isNotEmpty) {
                  onAttachmentsSelected(paths);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
