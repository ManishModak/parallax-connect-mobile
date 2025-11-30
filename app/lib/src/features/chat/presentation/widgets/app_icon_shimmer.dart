import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class AppIconShimmer extends StatefulWidget {
  const AppIconShimmer({super.key});

  @override
  State<AppIconShimmer> createState() => _AppIconShimmerState();
}

class _AppIconShimmerState extends State<AppIconShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20 * _controller.value,
                        spreadRadius: 2 * _controller.value,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logov1.png',
                    color: AppColors.primary,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.auto_awesome,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
