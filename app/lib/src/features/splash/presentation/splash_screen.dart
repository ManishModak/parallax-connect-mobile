import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/storage/config_storage.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../config/presentation/config_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final configStorage = ref.read(configStorageProvider);
    final hasConfig = configStorage.hasConfig();

    if (hasConfig) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConfigScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
                  'assets/images/gradient_logo.png',
                  width: 120,
                  height: 120,
                )
                .animate()
                .fadeIn(duration: 1000.ms, curve: Curves.easeIn)
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
                    letterSpacing: 1.2,
                  ),
                )
                .animate()
                .fadeIn(delay: 500.ms, duration: 800.ms)
                .moveY(begin: 10, end: 0),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              'The Sovereign AI Interface',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.secondary,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 800.ms),

            const Spacer(),

            // Footer
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Column(
                children: [
                  Text(
                    'Powered by Gradient',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hosted by You. Accessible Anywhere.',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 1200.ms, duration: 1000.ms),
            ),
          ],
        ),
      ),
    );
  }
}
