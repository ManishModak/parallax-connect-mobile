import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/storage/chat_archive_storage.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/logger.dart';
import 'chat_controller.dart';
import 'archived_session_detail_screen.dart';

class ArchivedSessionsScreen extends ConsumerStatefulWidget {
  const ArchivedSessionsScreen({super.key});

  @override
  ConsumerState<ArchivedSessionsScreen> createState() =>
      _ArchivedSessionsScreenState();
}

class _ArchivedSessionsScreenState
    extends ConsumerState<ArchivedSessionsScreen> {
  String _searchQuery = '';
  List<ChatSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    setState(() {
      _isLoading = true;
    });

    final archiveStorage = ref.read(chatArchiveStorageProvider);
    var sessions = _searchQuery.isEmpty
        ? archiveStorage.getArchivedSessions()
        : archiveStorage.searchSessions(_searchQuery);

    // Include current active chat if it exists
    final currentMessages = ref.read(chatControllerProvider).messages;

    if (currentMessages.isNotEmpty) {
      final currentSession = ChatSession(
        id: 'current_active',
        title: '💬 Current Chat',
        messages: currentMessages.map((m) => m.toMap()).toList(),
        timestamp: DateTime.now(),
        messageCount: currentMessages.length,
      );
      sessions = [currentSession, ...sessions];
    }

    Log.d('Loaded ${sessions.length} sessions');

    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Session'),
            content: const Text(
              'Are you sure you want to delete this session?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteSession(String sessionId) async {
    final confirmed = await _showDeleteConfirmation();

    if (confirmed && mounted) {
      final archiveStorage = ref.read(chatArchiveStorageProvider);
      await archiveStorage.deleteSession(sessionId);
      _loadSessions();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to chat controller changes and reload sessions
    ref.listen(chatControllerProvider, (previous, next) {
      // Reload when messages change
      if (previous?.messages.length != next.messages.length) {
        _loadSessions();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Archived Sessions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _loadSessions();
              },
              decoration: InputDecoration(
                hintText: 'Search sessions...',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? _buildEmptyState()
          : _buildSessionsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.archive, size: 64, color: AppColors.secondary),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No archived sessions' : 'No sessions found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Start new chats to create archived sessions'
                : 'Try a different search query',
            style: TextStyle(fontSize: 14, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(ChatSession session) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(session.id),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(LucideIcons.trash2, color: Colors.white),
        ),
        onDismissed: (_) => _deleteSession(session.id),
        confirmDismiss: (_) => _showDeleteConfirmation(),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ArchivedSessionDetailScreen(session: session),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(session.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      LucideIcons.messageSquare,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${session.messageCount} messages',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
