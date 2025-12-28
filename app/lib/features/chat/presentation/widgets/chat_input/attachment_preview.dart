import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../features/chat/utils/file_type_helper.dart';

/// Attachment preview widget showing selected attachments
class AttachmentPreview extends StatelessWidget {
  final List<String> attachments;
  final Function(int) onRemove;

  const AttachmentPreview({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final path = attachments[index];
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
                top: 0,
                right: 0,
                child: Semantics(
                  label: 'Remove attachment',
                  button: true,
                  child: Tooltip(
                    message: 'Remove attachment',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onRemove(index),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(
                              alpha: 0.6,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.x,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
