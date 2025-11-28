import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/export_service.dart';
import '../../../core/storage/chat_archive_storage.dart';

import '../../../core/utils/haptics_helper.dart';
import 'chat_controller.dart';
import 'widgets/delete_confirmation_dialog.dart';
import 'widgets/history_item_tile.dart';
import 'widgets/rename_dialog.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  Timer? _debounceTimer;
  List<ChatSession> _sessions = [];
  Map<String, List<ChatSession>> _categorizedSessions = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadSessions() {
    final archiveStorage = ref.read(chatArchiveStorageProvider);
    final sessions = _searchQuery.isEmpty
        ? archiveStorage.getArchivedSessions()
        : archiveStorage.searchSessions(_searchQuery);

    setState(() {
      _sessions = sessions;
      if (_searchQuery.isEmpty) {
        _categorizedSessions = _categorizeSessions(sessions);
      }
    });
  }

  Map<String, List<ChatSession>> _categorizeSessions(
    List<ChatSession> sessions,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final categorized = <String, List<ChatSession>>{
      'Today': [],
      'Yesterday': [],
      'Previous 7 Days': [],
      'Older': [],
    };

    for (final session in sessions) {
      final sessionDate = DateTime(
        session.timestamp.year,
        session.timestamp.month,
        session.timestamp.day,
      );

      if (sessionDate == today) {
        categorized['Today']!.add(session);
      } else if (sessionDate == yesterday) {
        categorized['Yesterday']!.add(session);
      } else if (sessionDate.isAfter(weekAgo)) {
        categorized['Previous 7 Days']!.add(session);
      } else {
        categorized['Older']!.add(session);
      }
    }

    // Sort each category: important first (except Today), then by timestamp
    for (final category in categorized.keys) {
      categorized[category]!.sort((a, b) {
        // For Today, only sort by timestamp (most recent first)
        if (category == 'Today') {
          return b.timestamp.compareTo(a.timestamp);
        }
        // For other categories, important first, then by timestamp
        if (a.isImportant && !b.isImportant) return -1;
        if (!a.isImportant && b.isImportant) return 1;
        return b.timestamp.compareTo(a.timestamp);
      });
    }

    // Remove empty categories
    categorized.removeWhere((key, value) => value.isEmpty);
    return categorized;
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('h:mm a').format(timestamp)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }

  Future<void> _handleDelete(ChatSession session) async {
    showDialog(
      context: context,
      builder: (dialogContext) => DeleteConfirmationDialog(
        sessionTitle: session.title,
        onDelete: () async {
          try {
            await ref
                .read(chatArchiveStorageProvider)
                .deleteSession(session.id);
            _loadSessions();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Chat deleted',
                    style: GoogleFonts.inter(color: AppColors.primary),
                  ),
                  backgroundColor: AppColors.surface,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to delete chat',
                    style: GoogleFonts.inter(color: AppColors.error),
                  ),
                  backgroundColor: AppColors.surface,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handleRename(ChatSession session) async {
    showDialog(
      context: context,
      builder: (dialogContext) => RenameDialog(
        currentTitle: session.title,
        onRename: (newTitle) async {
          try {
            await ref
                .read(chatArchiveStorageProvider)
                .renameSession(session.id, newTitle);
            _loadSessions();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to rename chat',
                    style: GoogleFonts.inter(color: AppColors.error),
                  ),
                  backgroundColor: AppColors.surface,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handleExport(ChatSession session) async {
    try {
      await ref.read(exportServiceProvider).exportSessionToPdf(session);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to export chat',
              style: GoogleFonts.inter(color: AppColors.error),
            ),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  Future<void> _handleToggleImportant(ChatSession session) async {
    try {
      await ref.read(chatArchiveStorageProvider).toggleImportant(session.id);
      _loadSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update chat',
              style: GoogleFonts.inter(color: AppColors.error),
            ),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for archive changes to trigger reload
    ref.listen(archiveRefreshProvider, (previous, next) {
      _loadSessions();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header: Search Bar + Close Icon
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          _debounceTimer?.cancel();
                          if (value.isEmpty) {
                            setState(() {
                              _searchQuery = '';
                              _isSearching = false;
                            });
                            _loadSessions();
                            return;
                          }
                          setState(() {
                            _isSearching = true;
                          });
                          _debounceTimer = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                                _isSearching = false;
                              });
                              _loadSessions();
                            },
                          );
                        },
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search chat history',
                          hintStyle: GoogleFonts.inter(
                            color: AppColors.secondary,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            color: AppColors.secondary,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? _isSearching
                                    ? Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.primary.withValues(
                                                    alpha: 0.7,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        icon: Icon(
                                          LucideIcons.x,
                                          color: AppColors.secondary,
                                          size: 18,
                                        ),
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          ref
                                              .read(hapticsHelperProvider)
                                              .triggerHaptics();
                                          _searchController.clear();
                                          _debounceTimer?.cancel();
                                          setState(() {
                                            _searchQuery = '';
                                            _isSearching = false;
                                          });
                                          _loadSessions();
                                        },
                                      )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: AppColors.secondary),
                    tooltip: 'Close history',
                    onPressed: () {
                      ref.read(hapticsHelperProvider).triggerHaptics();
                      context.pop();
                    },
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isSearching
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Searching...',
                            style: GoogleFonts.inter(
                              color: AppColors.secondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        if (_searchQuery.isEmpty)
                          _buildCategorizedList()
                        else
                          _buildSearchResults(),
                      ],
                    ),
            ),

            // New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(hapticsHelperProvider).triggerHaptics();
                    ref.read(chatControllerProvider.notifier).startNewChat();
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.plus, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'New Chat',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Image.asset(
                    'assets/images/logov1.png',
                    width: 28,
                    height: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Parallax Connect v1.0',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 40),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.settings,
                      color: AppColors.secondary,
                    ),
                    tooltip: 'Open settings',
                    onPressed: () {
                      ref.read(hapticsHelperProvider).triggerHaptics();
                      context.push(AppRoutes.settings);
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.monitorSmartphone,
                      color: AppColors.secondary,
                    ),
                    tooltip: 'Open Connection Setup',
                    onPressed: () {
                      ref.read(hapticsHelperProvider).triggerHaptics();
                      context.push(AppRoutes.config);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorizedList() {
    if (_categorizedSessions.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.messageSquare,
                size: 48,
                color: AppColors.secondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No chat history',
                style: GoogleFonts.inter(
                  color: AppColors.secondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start a new chat to see it here',
                style: GoogleFonts.inter(
                  color: AppColors.secondary.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentSessionId = ref.read(chatControllerProvider).currentSessionId;

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = _categorizedSessions.keys.elementAt(index);
        final sessions = _categorizedSessions[category]!;

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
                        time: _formatRelativeTime(session.timestamp),
                        isActive: session.id == currentSessionId,
                        isImportant: session.isImportant,
                        onTap: () {
                          ref
                              .read(chatControllerProvider.notifier)
                              .loadArchivedSession(session.id);
                          context.pop();
                        },
                        onDelete: () => _handleDelete(session),
                        onRename: () => _handleRename(session),
                        onExport: () => _handleExport(session),
                        onToggleImportant: () =>
                            _handleToggleImportant(session),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }, childCount: _categorizedSessions.length),
    );
  }

  Widget _buildSearchResults() {
    if (_sessions.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.searchX,
                size: 48,
                color: AppColors.secondary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No chats found',
                style: GoogleFonts.inter(
                  color: AppColors.secondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                style: GoogleFonts.inter(
                  color: AppColors.secondary.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentSessionId = ref.read(chatControllerProvider).currentSessionId;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final session = _sessions[index];
          return HistoryItemTile(
            title: session.title,
            time: _formatRelativeTime(session.timestamp),
            isActive: session.id == currentSessionId,
            isImportant: session.isImportant,
            onTap: () {
              ref
                  .read(chatControllerProvider.notifier)
                  .loadArchivedSession(session.id);
              context.pop();
            },
            onDelete: () => _handleDelete(session),
            onRename: () => _handleRename(session),
            onExport: () => _handleExport(session),
            onToggleImportant: () => _handleToggleImportant(session),
          );
        }, childCount: _sessions.length),
      ),
    );
  }
}
