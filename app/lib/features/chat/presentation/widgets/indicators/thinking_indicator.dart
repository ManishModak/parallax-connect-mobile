import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../app/constants/app_colors.dart';

/// A widget that displays the model's thinking process with a rolling display
/// Shows 4-6 lines at a time, cycling through the thinking content
class ThinkingIndicator extends StatefulWidget {
  final String thinkingContent;
  final bool isThinking;

  const ThinkingIndicator({
    super.key,
    required this.thinkingContent,
    required this.isThinking,
  });

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Rolling display state
  int _startLineIndex = 0;
  Timer? _scrollTimer;
  static const int _visibleLines = 5;
  static const Duration _scrollInterval = Duration(milliseconds: 2500);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startScrollTimer();
  }

  @override
  void didUpdateWidget(ThinkingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thinkingContent != oldWidget.thinkingContent) {
      // Reset scroll when content changes significantly
      final newLines = _getLines();
      if (newLines.length <= _visibleLines) {
        _startLineIndex = 0;
      }
    }
  }

  void _startScrollTimer() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(_scrollInterval, (_) {
      if (!mounted) return;
      final lines = _getLines();
      if (lines.length > _visibleLines) {
        setState(() {
          _startLineIndex =
              (_startLineIndex + 1) % (lines.length - _visibleLines + 1);
        });
      }
    });
  }

  List<String> _getLines() {
    if (widget.thinkingContent.isEmpty) return [];

    // Split by newlines and filter empty lines
    final lines = widget.thinkingContent
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    // If we have very long lines, split them further
    final processedLines = <String>[];
    for (final line in lines) {
      if (line.length > 80) {
        // Split long lines
        final words = line.split(' ');
        var currentLine = '';
        for (final word in words) {
          if ((currentLine + word).length > 80) {
            if (currentLine.isNotEmpty) {
              processedLines.add(currentLine.trim());
            }
            currentLine = '$word ';
          } else {
            currentLine += '$word ';
          }
        }
        if (currentLine.isNotEmpty) {
          processedLines.add(currentLine.trim());
        }
      } else {
        processedLines.add(line);
      }
    }

    return processedLines;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _getLines();
    final visibleLines = lines.isEmpty
        ? <String>[]
        : lines.sublist(
            _startLineIndex,
            (_startLineIndex + _visibleLines).clamp(0, lines.length),
          );

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accent.withValues(
                alpha: 0.3 * _pulseAnimation.value,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      return Icon(
                        LucideIcons.brain,
                        size: 16,
                        color: AppColors.accent.withValues(
                          alpha: _pulseAnimation.value,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thinking...',
                    style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (lines.length > _visibleLines)
                    Text(
                      '${_startLineIndex + 1}-${(_startLineIndex + visibleLines.length).clamp(0, lines.length)} of ${lines.length}',
                      style: GoogleFonts.inter(
                        color: AppColors.secondary.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Thinking content with rolling display
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(_startLineIndex),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: visibleLines.isEmpty
                      ? [_buildThinkingDots()]
                      : visibleLines
                            .map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  line,
                                  style: GoogleFonts.inter(
                                    color: AppColors.secondary,
                                    fontSize: 13,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThinkingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: Duration(milliseconds: 600 + (index * 200)),
          builder: (context, value, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: value),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
