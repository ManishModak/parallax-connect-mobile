import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import 'attachment_menu.dart';

class ChatInputArea extends StatefulWidget {
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
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _selectedAttachments = [];
  bool _isAttachmentMenuOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleAttachmentMenu() {
    if (_isAttachmentMenuOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
    setState(() {
      _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
    });
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
                _removeOverlay();
                setState(() => _isAttachmentMenuOpen = false);
                final path = await widget.onCameraTap();
                if (path != null) {
                  setState(() {
                    _selectedAttachments.add(path);
                  });
                }
              },
              onGalleryTap: () async {
                _removeOverlay();
                setState(() => _isAttachmentMenuOpen = false);
                final paths = await widget.onGalleryTap();
                if (paths.isNotEmpty) {
                  setState(() {
                    _selectedAttachments.addAll(paths);
                  });
                }
              },
              onFileTap: () async {
                _removeOverlay();
                setState(() => _isAttachmentMenuOpen = false);
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

  void _handleSubmit() {
    final text = _controller.text.trim();
    if ((text.isNotEmpty || _selectedAttachments.isNotEmpty) &&
        !widget.isLoading) {
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
                      // Simple check for image extension
                      final isImage =
                          path.toLowerCase().endsWith('.jpg') ||
                          path.toLowerCase().endsWith('.jpeg') ||
                          path.toLowerCase().endsWith('.png') ||
                          path.toLowerCase().endsWith('.webp');

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
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.x,
                                  size: 12,
                                  color: Colors.white,
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
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Ask anything',
                  hintStyle: GoogleFonts.inter(color: AppColors.secondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
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
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          LucideIcons.paperclip,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        onPressed: _toggleAttachmentMenu,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
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
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              LucideIcons.arrowUp,
                              size: 20,
                              color: Colors.black,
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
