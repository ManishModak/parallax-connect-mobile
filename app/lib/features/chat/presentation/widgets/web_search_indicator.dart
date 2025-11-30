import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../app/constants/app_colors.dart';

class WebSearchIndicator extends StatefulWidget {
  const WebSearchIndicator({super.key});

  @override
  State<WebSearchIndicator> createState() => _WebSearchIndicatorState();
}

class _WebSearchIndicatorState extends State<WebSearchIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _textIndex = 0;
  Timer? _textTimer;

  final List<String> _searchStates = [
    'Searching the web...',
    'Analyzing results...',
    'Synthesizing information...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _textTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _textIndex = (_textIndex + 1) % _searchStates.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _textTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _controller,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.0),
                    AppColors.primary,
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
              child: const Icon(
                LucideIcons.globe,
                size: 16,
                color: AppColors.background,
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.5),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _searchStates[_textIndex],
              key: ValueKey<int>(_textIndex),
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
