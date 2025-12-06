import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../app/routes/app_router.dart';
import '../../../../core/services/storage/config_storage.dart';
import '../../../../app/constants/app_constants.dart';

import '../widgets/splash_branding.dart';
import '../../../chat/data/repositories/chat_repository.dart';
import '../../../../core/services/ai/model_selection_service.dart';

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
    final configStorage = ref.read(configStorageProvider);
    final hasConfig = configStorage.hasConfig();

    // 🧪 In test mode, skip config screen
    if (TestConfig.enabled) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) context.go(AppRoutes.chat);
      return;
    }

    if (hasConfig) {
      // User already configured - quick splash then go to chat
      final minSplashDuration = Future.delayed(
        const Duration(milliseconds: 1200),
      );

      // Start connection test in background immediately
      final repository = ref.read(chatRepositoryProvider);
      final connectionFuture = repository.testConnection();

      // Wait for the quick splash animation
      await minSplashDuration;

      // Check connection with small timeout
      bool isConnected = false;
      try {
        isConnected = await connectionFuture.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => false,
        );
      } catch (e) {
        // Ignore connection errors here
      }

      if (!mounted) return;

      if (isConnected) {
        // Fetch available models in background (fire and forget)
        ref.read(modelSelectionProvider.notifier).fetchModels();
      }
      // Go to chat regardless - it handles offline state gracefully
      context.go(AppRoutes.chat);
    } else {
      // First-time user - show full splash then config
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go(AppRoutes.config);
    }
  }

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
                Image.asset('assets/images/logov1.png', width: 100, height: 100)
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
            child: const SplashBranding().animate().fadeIn(
              delay: 1000.ms,
              duration: 800.ms,
            ),
          ),
        ],
      ),
    );
  }
}
