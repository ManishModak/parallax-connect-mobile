import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';

class SearchingIndicator extends ConsumerWidget {
  final String statusMessage;
  final bool isSearching;

  const SearchingIndicator({
    super.key,
    required this.statusMessage,
    required this.isSearching,
  });

  IconData _getIconForStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('searching')) return LucideIcons.search;
    if (s.contains('browsing') || s.contains('reading')) {
      return LucideIcons.globe;
    }
    if (s.contains('found') || s.contains('result')) {
      return LucideIcons.fileText;
    }
    if (s.contains('analyzing')) return LucideIcons.brainCircuit;
    return LucideIcons.loader;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = _getIconForStatus(statusMessage);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with subtle animation if searching
          if (isSearching)
            _PulsingIcon(icon: icon)
          else
            Icon(icon, size: 16, color: AppColors.secondary),

          const SizedBox(width: 12),

          // Status Text
          Flexible(
            child: Text(
              statusMessage,
              style: GoogleFonts.inter(
                color: AppColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;

  const _PulsingIcon({required this.icon});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    // Use elasticOut for spring-like feel
    _opacity = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scale = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Opacity(
            opacity: _opacity.value,
            child: Icon(widget.icon, size: 16, color: AppColors.primary),
          ),
        );
      },
    );
  }
}
