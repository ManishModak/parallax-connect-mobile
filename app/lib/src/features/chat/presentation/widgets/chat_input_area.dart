import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/feature_flags_service.dart';
import '../../../../core/services/model_selection_service.dart';
import '../../../../core/utils/feature_snackbar.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../utils/file_type_helper.dart';
import '../../../settings/presentation/settings_controller.dart';
import 'attachment_menu.dart';
import 'search_options_menu.dart';

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
      _removeSearchOptionsOverlay(); // Close other menu if open
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
      _removeOverlay(); // Close attachment menu if open
      _showSearchOptionsOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showSearchOptionsOverlay() {
    _searchOptionsOverlayEntry = _createSearchOptionsOverlayEntry();
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

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -180), // Position above the icon
          child: TapRegion(
            groupId: 'attachment_menu',
            child: AttachmentMenu(
              onCameraTap: () async {
                ref.read(hapticsHelperProvider).triggerHaptics();
                _removeOverlay();
                final path = await widget.onCameraTap();
                if (path != null) {
                  setState(() {
                    _selectedAttachments.add(path);
                  });
                }
              },
              onGalleryTap: () async {
                ref.read(hapticsHelperProvider).triggerHaptics();
                _removeOverlay();
                final paths = await widget.onGalleryTap();
                if (paths.isNotEmpty) {
                  setState(() {
                    _selectedAttachments.addAll(paths);
                  });
                }
              },
              onFileTap: () async {
                ref.read(hapticsHelperProvider).triggerHaptics();
                _removeOverlay();
                final paths = await widget.onFileTap();
                if (paths.isNotEmpty) {
                  setState(() {
                    _selectedAttachments.addAll(paths);
                  });
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  OverlayEntry _createSearchOptionsOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 260,
        child: CompositedTransformFollower(
          link: _searchOptionsLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -140), // Position above the icon
          child: TapRegion(
            groupId: 'search_options_menu',
            onTapOutside: (_) => _removeSearchOptionsOverlay(),
            child: SearchOptionsMenu(
              onWebSearchToggle: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                final controller = ref.read(
                  settingsControllerProvider.notifier,
                );
                final isEnabled = ref
                    .read(settingsControllerProvider)
                    .isWebSearchEnabled;
                controller.setWebSearchEnabled(!isEnabled);
              },
              onDeepSearchToggle: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                final controller = ref.read(
                  settingsControllerProvider.notifier,
                );
                final isDeep = ref
                    .read(settingsControllerProvider)
                    .isDeepSearchEnabled;
                controller.setDeepSearchEnabled(!isDeep);
              },
            ),
          ),
        ),
      ),
    );
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
            // Show snackbar explaining why attachments are disabled
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

  Widget _buildModelSelector() {
    final modelState = ref.watch(modelSelectionProvider);
    final activeModel = modelState.activeModel;

    // Show active model name, or "No Model" if scheduler not initialized
    final displayName = activeModel?.name ?? 'No Model';
    // Truncate long model names (e.g., "Qwen/Qwen3-0.6B" -> "Qwen3-0.6B")
    final shortName = displayName.contains('/')
        ? displayName.split('/').last
        : displayName;

    return GestureDetector(
      onTap: () {
        ref.read(hapticsHelperProvider).triggerHaptics();
        _showModelInfoSnackbar(modelState);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: modelState.hasActiveModel
              ? AppColors.surfaceLight.withValues(alpha: 0.5)
              : AppColors.warning.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.cpu,
              size: 14,
              color: modelState.hasActiveModel
                  ? AppColors.secondary
                  : AppColors.warning,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                shortName,
                style: GoogleFonts.inter(
                  color: modelState.hasActiveModel
                      ? AppColors.secondary
                      : AppColors.warning,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebSearchToggle() {
    final settingsState = ref.watch(settingsControllerProvider);
    final isEnabled = settingsState.isWebSearchEnabled;

    return GestureDetector(
      onTap: () {
        ref.read(hapticsHelperProvider).triggerHaptics();
        _toggleSearchOptionsMenu();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceLight.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.globe,
          size: 18,
          color: isEnabled
              ? AppColors.primary
              : AppColors.secondary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  void _showModelInfoSnackbar(ModelSelectionState modelState) {
    final activeModel = modelState.activeModel;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              modelState.hasActiveModel
                  ? LucideIcons.cpu
                  : LucideIcons.alertCircle,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modelState.hasActiveModel
                        ? activeModel!.name
                        : 'No model running',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Change model in Parallax Web UI',
                    style: GoogleFonts.inter(
                      color: AppColors.primaryMildVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: modelState.hasActiveModel
            ? AppColors.surfaceLight
            : AppColors.warning.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
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
              if (_selectedAttachments.isNotEmpty)
                Container(
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedAttachments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final path = _selectedAttachments[index];
                      final isImage = FileTypeHelper.isImageFile(path);

                      return Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.surfaceLight),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isImage
                                ? Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(
                                          LucideIcons.image,
                                          color: AppColors.secondary,
                                        ),
                                      );
                                    },
                                  )
                                : const Center(
                                    child: Icon(
                                      LucideIcons.file,
                                      color: AppColors.secondary,
                                      size: 32,
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeAttachment(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.background.withValues(
                                    alpha: 0.6,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.x,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
                    child: _buildWebSearchToggle(),
                  ),
                  const SizedBox(width: 8),
                  // Model Selector
                  _buildModelSelector(),
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
