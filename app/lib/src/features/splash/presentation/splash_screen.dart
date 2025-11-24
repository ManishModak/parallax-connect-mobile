import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/config_storage.dart';

import '../../../core/constants/app_constants.dart';

import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // 🧪 In test mode, skip config screen
    if (TestConfig.enabled) {
      context.go(AppRoutes.chat);
      return;
    }

    final configStorage = ref.read(configStorageProvider);
    final hasConfig = configStorage.hasConfig();

    if (hasConfig) {
      context.go(AppRoutes.chat);
    } else {
      context.go(AppRoutes.config);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Center Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 100,
                      height: 100,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primary,
                        BlendMode.srcIn,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 800.ms, curve: Curves.easeIn)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.0, 1.0),
                    ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Parallax Connect',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'The Sovereign AI Interface',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.secondary,
                    letterSpacing: 0.5,
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
              ],
            ),
          ),

          // Bottom Content
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
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

                // Gradient Logo
                const SizedBox(height: 12),

                Text(
                  'Hosted by You. Accessible Anywhere.',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 1000.ms, duration: 800.ms),
          ),
        ],
      ),
    );
  }
}
