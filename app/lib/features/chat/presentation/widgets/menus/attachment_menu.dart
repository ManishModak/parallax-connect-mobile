import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../app/constants/app_colors.dart';

class AttachmentMenu extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onFileTap;

  const AttachmentMenu({
    super.key,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors
              .chatInputBackground, // Dark background matching screenshot
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.background.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              icon: LucideIcons.camera,
              label: 'Camera',
              onTap: onCameraTap,
            ),
            const SizedBox(height: 4),
            _buildMenuItem(
              icon: LucideIcons.image,
              label: 'Photos',
              onTap: onGalleryTap,
            ),
            const SizedBox(height: 4),
            _buildMenuItem(
              icon: LucideIcons.file,
              label: 'Files',
              onTap: onFileTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
