import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/constants/app_colors.dart';
import '../../../../../core/storage/models/chat_session.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../widgets/history_item_tile.dart';
import 'empty_states.dart';

typedef SessionCallback = void Function(ChatSession session);

class HistoryCategorizedList extends StatelessWidget {
  final Map<String, List<ChatSession>> categorizedSessions;
  final String? currentSessionId;
  final SessionCallback onSessionTap;
  final SessionCallback onDelete;
  final SessionCallback onRename;
  final SessionCallback onExport;
  final SessionCallback onToggleImportant;

  const HistoryCategorizedList({
    super.key,
    required this.categorizedSessions,
    required this.currentSessionId,
    required this.onSessionTap,
    required this.onDelete,
    required this.onRename,
    required this.onExport,
    required this.onToggleImportant,
  });

  @override
  Widget build(BuildContext context) {
    if (categorizedSessions.isEmpty) {
      return const SliverFillRemaining(child: HistoryEmptyState());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = categorizedSessions.keys.elementAt(index);
        final sessions = categorizedSessions[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 8, bottom: 12),
              child: Text(
                category,
                style: GoogleFonts.inter(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: sessions
                    .map(
                      (session) => HistoryItemTile(
                        title: session.title,
                        time: DateFormatter.formatRelativeTime(
                          session.timestamp,
                        ),
                        isActive: session.id == currentSessionId,
                        isImportant: session.isImportant,
                        onTap: () => onSessionTap(session),
                        onDelete: () => onDelete(session),
                        onRename: () => onRename(session),
                        onExport: () => onExport(session),
                        onToggleImportant: () => onToggleImportant(session),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }, childCount: categorizedSessions.length),
    );
  }
}
