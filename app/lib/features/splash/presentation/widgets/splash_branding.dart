import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/constants/app_colors.dart';

class SplashBranding extends StatelessWidget {
  const SplashBranding({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Powered by Gradient Parallax',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/gradient_logo.png',
              width: 20,
              height: 20,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Hosted by You. Accessible Anywhere.',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

