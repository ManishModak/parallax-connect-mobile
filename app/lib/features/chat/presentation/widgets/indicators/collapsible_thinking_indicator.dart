import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/utils/haptics_helper.dart';

class CollapsibleThinkingIndicator extends ConsumerStatefulWidget {
  final String thinkingContent;
  final bool isThinking;

  const CollapsibleThinkingIndicator({
    super.key,
    required this.thinkingContent,
    required this.isThinking,
  });

  @override
  ConsumerState<CollapsibleThinkingIndicator> createState() =>
      _CollapsibleThinkingIndicatorState();
}

class _CollapsibleThinkingIndicatorState
    extends ConsumerState<CollapsibleThinkingIndicator>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _heightFactor = _controller.view;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    ref.read(hapticsHelperProvider).triggerHaptics();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: _isExpanded
            ? AppColors.surfaceLight.withValues(alpha: 0.5)
            : AppColors.surfaceLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded
              ? AppColors.surfaceLight
              : AppColors.surfaceLight.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (widget.isThinking) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ] else ...[
                    Icon(
                      LucideIcons.brainCircuit,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    widget.isThinking ? 'Thinking...' : 'Thought Process',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  RotationTransition(
                    turns: _iconTurns,
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Align(
                  heightFactor: _heightFactor.value,
                  alignment: Alignment.topCenter,
                  child: child,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: AppColors.surfaceLight),
                    const SizedBox(height: 12),
                    Text(
                      widget.thinkingContent,
                      style: GoogleFonts.firaCode(
                        color: AppColors.secondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
