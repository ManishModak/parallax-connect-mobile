import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';

class WebSearchMenu extends StatelessWidget {
  final VoidCallback onDeep;
  final VoidCallback onNormal;
  final VoidCallback onDeeper;
  final VoidCallback onOff;

  const WebSearchMenu({
    super.key,
    required this.onDeep,
    required this.onNormal,
    required this.onDeeper,
    required this.onOff,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.chatInputBackground,
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
              icon: LucideIcons.globe,
              title: 'Deep Search',
              subtitle: 'Multi-phase analysis',
              onTap: onDeep,
            ),
            const SizedBox(height: 4),
            _buildMenuItem(
              icon: LucideIcons.zap,
              title: 'Normal Search',
              subtitle: 'Fast check',
              onTap: onNormal,
            ),
            const SizedBox(height: 4),
            _buildMenuItem(
              icon: LucideIcons.layers,
              title: 'Deeper Search',
              subtitle: 'Ultra-intensive research',
              onTap: onDeeper,
            ),
            const SizedBox(height: 4),
            _buildMenuItem(
              icon: LucideIcons.xCircle,
              title: 'Turn Off',
              subtitle: 'Disable web search',
              onTap: onOff,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppColors.error : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isDestructive ? AppColors.error : AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

