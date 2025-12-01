import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/constants/app_colors.dart';

class ConnectionValidator {
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a URL';
    }
    if (!value.startsWith('http')) {
      return 'URL must start with http:// or https://';
    }
    return null;
  }

  static InputDecoration buildUrlDecoration({
    required bool isLocal,
  }) {
    return InputDecoration(
      hintText:
          isLocal ? 'http://192.168.1.X:8000' : 'https://xxxx-xx.ngrok-free.app',
      hintStyle: GoogleFonts.sourceCodePro(color: AppColors.accent),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary),
      ),
    );
  }
}


