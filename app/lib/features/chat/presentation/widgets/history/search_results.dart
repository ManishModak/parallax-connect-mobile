import 'package:flutter/material.dart';

import '../../../../../core/services/storage/models/chat_session.dart';
import '../../../../../core/utils/date_formatter.dart';
import 'history_item_tile.dart';
import 'empty_states.dart';

typedef SessionCallback = void Function(ChatSession session);

class HistorySearchResults extends StatelessWidget {
  final List<ChatSession> sessions;
  final String? currentSessionId;
  final SessionCallback onSessionTap;
  final SessionCallback onDelete;
  final void Function(ChatSession session, String newTitle) onRename;
  final SessionCallback onExport;
  final SessionCallback onToggleImportant;

  const HistorySearchResults({
    super.key,
    required this.sessions,
    required this.currentSessionId,
    required this.onSessionTap,
    required this.onDelete,
    required this.onRename,
    required this.onExport,
    required this.onToggleImportant,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const SliverFillRemaining(child: HistorySearchEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final session = sessions[index];
          return HistoryItemTile(
            title: session.title,
            time: DateFormatter.formatRelativeTime(session.timestamp),
            isActive: session.id == currentSessionId,
            isImportant: session.isImportant,
            onTap: () => onSessionTap(session),
            onDelete: () => onDelete(session),
            onRename: (newTitle) => onRename(session, newTitle),
            onExport: () => onExport(session),
            onToggleImportant: () => onToggleImportant(session),
          );
        }, childCount: sessions.length),
      ),
    );
  }
}
