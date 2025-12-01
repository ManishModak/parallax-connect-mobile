import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../app/routes/app_router.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/services/storage/chat_archive_storage.dart';
import '../../../../core/utils/feature_snackbar.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../view_models/chat_controller.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/rename_dialog.dart';
import '../widgets/history/categorized_list.dart';
import '../widgets/history/search_bar.dart';
import '../widgets/history/search_results.dart';

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

  void _onSearchChanged(String value) {
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

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value.toLowerCase();
        _isSearching = false;
      });
      _loadSessions();
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
      _searchController.clear();
    });
    _loadSessions();
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
              FeatureSnackbar.showSuccess(context, message: 'Chat deleted');
            }
          } catch (e) {
            if (mounted) {
              FeatureSnackbar.showError(
                context,
                message: 'Failed to delete chat',
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
              FeatureSnackbar.showError(
                context,
                message: 'Failed to rename chat',
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
        FeatureSnackbar.showError(context, message: 'Failed to export chat');
      }
    }
  }

  Future<void> _handleToggleImportant(ChatSession session) async {
    try {
      await ref.read(chatArchiveStorageProvider).toggleImportant(session.id);
      _loadSessions();
    } catch (e) {
      if (mounted) {
        FeatureSnackbar.showError(context, message: 'Failed to update chat');
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
            HistorySearchBar(
              controller: _searchController,
              isSearching: _isSearching,
              debounceTimer: _debounceTimer,
              onChangedWithDebounce: (value, _) => _onSearchChanged(value),
              onClear: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                _clearSearch();
              },
              onClose: () {
                ref.read(hapticsHelperProvider).triggerHaptics();
                context.pop();
              },
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
                          HistoryCategorizedList(
                            categorizedSessions: _categorizedSessions,
                            currentSessionId: ref
                                .read(chatControllerProvider)
                                .currentSessionId,
                            onSessionTap: (session) {
                              ref
                                  .read(chatControllerProvider.notifier)
                                  .loadArchivedSession(session.id);
                              context.pop();
                            },
                            onDelete: _handleDelete,
                            onRename: _handleRename,
                            onExport: _handleExport,
                            onToggleImportant: _handleToggleImportant,
                          )
                        else
                          HistorySearchResults(
                            sessions: _sessions,
                            currentSessionId: ref
                                .read(chatControllerProvider)
                                .currentSessionId,
                            onSessionTap: (session) {
                              ref
                                  .read(chatControllerProvider.notifier)
                                  .loadArchivedSession(session.id);
                              context.pop();
                            },
                            onDelete: _handleDelete,
                            onRename: _handleRename,
                            onExport: _handleExport,
                            onToggleImportant: _handleToggleImportant,
                          ),
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
}
