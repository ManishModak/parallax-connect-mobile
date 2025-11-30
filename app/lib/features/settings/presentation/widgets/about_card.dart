import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/constants/app_colors.dart';

class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parallax Connect transforms your device into an intelligent edge node. By leveraging the Neural Engine (NPU) in modern smartphones for vision processing and OCR, we offload heavy lifting from the server, ensuring the GPU is dedicated strictly to reasoning. This architecture enables powerful AI capabilities on commodity hardware.',
            style: GoogleFonts.inter(
              color: AppColors.secondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
