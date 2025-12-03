import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../app/routes/app_router.dart';
import '../../../../core/services/server/feature_flags_service.dart';
import '../../../../core/utils/feature_snackbar.dart';
import '../../../../core/utils/haptics_helper.dart';
import 'chat_input/attachment_menu_handler.dart';
import 'chat_input/attachment_preview.dart';
import 'chat_input/model_selector.dart';
import 'chat_input/web_search_mode_selector.dart';
import '../view_models/chat_controller.dart';

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
  final FocusNode _focusNode = FocusNode();
  final List<String> _selectedAttachments = [];
  bool _isAttachmentMenuOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleAttachmentMenu() {
    // Dismiss keyboard first
    _focusNode.unfocus();

    if (_isAttachmentMenuOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
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
    setState(() => _isAttachmentMenuOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_isAttachmentMenuOpen) {
      setState(() => _isAttachmentMenuOpen = false);
    }
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    final chatState = ref.read(chatControllerProvider);
    final isEditing = chatState.editingMessage != null;

    if ((text.isNotEmpty || _selectedAttachments.isNotEmpty) &&
        !widget.isLoading) {
      ref.read(hapticsHelperProvider).triggerHaptics();

      if (isEditing) {
        ref.read(chatControllerProvider.notifier).submitEdit(text);
      } else {
        widget.onSubmitted(text, List.from(_selectedAttachments));
      }

      _controller.clear();
      _focusNode.unfocus();
      setState(() {
        _selectedAttachments.clear();
      });
    }
  }

  void _handleCancelEdit() {
    ref.read(hapticsHelperProvider).triggerHaptics();
    ref.read(chatControllerProvider.notifier).cancelEditing();
    _controller.clear();
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
            ref.read(hapticsHelperProvider).triggerHaptics();
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
    final chatState = ref.watch(chatControllerProvider);
    final isEditing = chatState.editingMessage != null;

    // Listen for editing state changes to populate text field
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.editingMessage != next.editingMessage) {
        if (next.editingMessage != null) {
          _controller.text = next.editingMessage!.text;
          // Move cursor to end
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
          // Don't auto-focus - user must tap to focus
        } else {
          // Cleared editing, clear text if it matches the old message (optional, but good for cancel)
          // Actually _handleCancelEdit clears it, so we might not need to do it here unless external cancel
          if (previous?.editingMessage != null) {
            _controller.clear();
            _focusNode.unfocus();
          }
        }
      }
    });

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
                focusNode: _focusNode,
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontSize: 16,
                ),
                maxLines: 6,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: isEditing ? 'Edit your message...' : 'Ask anything',
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
                  // Scrollable Middle Section
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Web Search Mode Selector
                          const WebSearchModeSelector(),
                          const SizedBox(width: 8),
                          // Model Selector
                          const ModelSelector(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cancel Edit Button
                  if (isEditing) ...[
                    IconButton(
                      icon: const Icon(
                        LucideIcons.x,
                        size: 20,
                        color: AppColors.secondary,
                      ),
                      onPressed: _handleCancelEdit,
                      tooltip: 'Cancel Edit',
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Send/Voice/Update Button
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
                          : Icon(
                              isEditing
                                  ? LucideIcons.check
                                  : LucideIcons.arrowUp,
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
