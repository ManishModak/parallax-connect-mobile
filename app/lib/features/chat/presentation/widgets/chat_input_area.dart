import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../app/routes/app_router.dart';
import '../../../../core/services/feature_flags_service.dart';
import '../../../../core/utils/feature_snackbar.dart';
import '../../../../core/utils/haptics_helper.dart';
import 'chat_input/attachment_menu_handler.dart';
import 'chat_input/attachment_preview.dart';
import 'chat_input/model_selector.dart';
import 'chat_input/search_options_handler.dart';
import 'chat_input/web_search_toggle.dart';

class ChatInputArea extends ConsumerStatefulWidget {
  final Function(String text, List<String> attachmentPaths) onSubmitted;
  final bool isLoading;
  final Future<String?> Function() onCameraTap;
  final Future<List<String>> Function() onGalleryTap;
  final Future<List<String>> Function() onFileTap;

  const ChatInputArea({
    super.key,
    required this.onSubmitted,
    required this.isLoading,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onFileTap,
  });

  @override
  ConsumerState<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends ConsumerState<ChatInputArea> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _selectedAttachments = [];
  bool _isAttachmentMenuOpen = false;
  final LayerLink _layerLink = LayerLink();
  final LayerLink _searchOptionsLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _searchOptionsOverlayEntry;

  @override
  void dispose() {
    _controller.dispose();
    _removeOverlay();
    _removeSearchOptionsOverlay();
    super.dispose();
  }

  void _toggleAttachmentMenu() {
    if (_isAttachmentMenuOpen) {
      _removeOverlay();
    } else {
      _removeSearchOptionsOverlay();
      _showOverlay();
    }
    setState(() {
      _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
    });
  }

  void _toggleSearchOptionsMenu() {
    if (_searchOptionsOverlayEntry != null) {
      _removeSearchOptionsOverlay();
    } else {
      _removeOverlay();
      _showSearchOptionsOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = AttachmentMenuHandler.createOverlayEntry(
      context: context,
      ref: ref,
      layerLink: _layerLink,
      onCameraTap: widget.onCameraTap,
      onGalleryTap: widget.onGalleryTap,
      onFileTap: widget.onFileTap,
      onRemoveOverlay: _removeOverlay,
      onAttachmentSelected: (path) {
        if (path != null) {
          setState(() {
            _selectedAttachments.add(path);
          });
        }
      },
      onAttachmentsSelected: (paths) {
        setState(() {
          _selectedAttachments.addAll(paths);
        });
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showSearchOptionsOverlay() {
    _searchOptionsOverlayEntry = SearchOptionsHandler.createOverlayEntry(
      context: context,
      ref: ref,
      layerLink: _searchOptionsLayerLink,
      onRemoveOverlay: _removeSearchOptionsOverlay,
    );
    Overlay.of(context).insert(_searchOptionsOverlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_isAttachmentMenuOpen) {
      setState(() => _isAttachmentMenuOpen = false);
    }
  }

  void _removeSearchOptionsOverlay() {
    _searchOptionsOverlayEntry?.remove();
    _searchOptionsOverlayEntry = null;
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if ((text.isNotEmpty || _selectedAttachments.isNotEmpty) &&
        !widget.isLoading) {
      ref.read(hapticsHelperProvider).triggerHaptics();
      widget.onSubmitted(text, List.from(_selectedAttachments));
      _controller.clear();
      setState(() {
        _selectedAttachments.clear();
      });
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _selectedAttachments.removeAt(index);
    });
  }

  Widget _buildAttachmentButton() {
    final featureFlags = ref.watch(featureFlagsProvider);
    final attachmentStatus = featureFlags.attachments;
    final isEnabled = attachmentStatus.canUse;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isEnabled
            ? AppColors.surfaceLight.withValues(alpha: 0.5)
            : AppColors.surfaceLight.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          LucideIcons.paperclip,
          size: 18,
          color: isEnabled
              ? AppColors.primary
              : AppColors.secondary.withValues(alpha: 0.5),
        ),
        onPressed: () {
          if (isEnabled) {
            _toggleAttachmentMenu();
          } else {
            ref.read(hapticsHelperProvider).triggerHaptics();
            FeatureSnackbar.showDisabled(
              context,
              featureName: 'Attachments',
              status: attachmentStatus,
              onSettingsTap: attachmentStatus.isAvailable
                  ? () => context.push(AppRoutes.settings)
                  : null,
            );
          }
        },
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: 'attachment_menu',
      onTapOutside: (_) {
        if (_isAttachmentMenuOpen) {
          _removeOverlay();
          setState(() {
            _isAttachmentMenuOpen = false;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.chatInputBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surfaceLight, width: 1),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attachment Previews
              AttachmentPreview(
                attachments: _selectedAttachments,
                onRemove: _removeAttachment,
              ),

              // Text Input
              TextField(
                controller: _controller,
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 16,
                ),
                maxLines: 6,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: 'Ask anything',
                  hintStyle: GoogleFonts.inter(color: AppColors.secondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _handleSubmit(),
              ),
              const SizedBox(height: 12),
              // Bottom Actions Row
              Row(
                children: [
                  // Attachment Button
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: _buildAttachmentButton(),
                  ),
                  const SizedBox(width: 8),
                  // Web Search Toggle with Options Menu
                  CompositedTransformTarget(
                    link: _searchOptionsLayerLink,
                    child: WebSearchToggle(
                      onLongPress: _toggleSearchOptionsMenu,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Model Selector
                  const ModelSelector(),
                  const Spacer(),
                  // Send/Voice Button
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: widget.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : const Icon(
                              LucideIcons.arrowUp,
                              size: 20,
                              color: AppColors.background,
                            ),
                      onPressed: _handleSubmit,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
