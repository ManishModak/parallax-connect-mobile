import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import 'chat_controller.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Mock data - categorized by time
  final Map<String, List<Map<String, String>>> _categorizedChats = {
    'Today': [
      {'title': 'Project Planning', 'time': '2 mins ago'},
      {'title': 'Flutter Architecture', 'time': '1 hour ago'},
    ],
    'Yesterday': [
      {'title': 'Dart Streams', 'time': 'Yesterday 3:45 PM'},
    ],
    'Previous 7 Days': [
      {'title': 'AI Integration', 'time': '2 days ago'},
      {'title': 'UI Design', 'time': '3 days ago'},
      {'title': 'Code Review', 'time': '5 days ago'},
    ],
    'Older': [
      {'title': 'Database Schema', 'time': '2 weeks ago'},
      {'title': 'API Design', 'time': '1 month ago'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with close and settings
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.secondary.withOpacity(0.1),
                        ),
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
                            },
                          );
                        },
                        style: GoogleFonts.inter(
                          color: AppColors.secondary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search chat history',
                          hintStyle: GoogleFonts.inter(
                            color: AppColors.secondary.withOpacity(0.5),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.search,
                            color: AppColors.secondary.withOpacity(0.5),
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
                                            AppColors.primary.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: Icon(
                                        LucideIcons.x,
                                        color: AppColors.secondary
                                            .withOpacity(0.5),
                                        size: 18,
                                      ),
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _searchController.clear();
                                        _debounceTimer?.cancel();
                                        setState(() {
                                          _searchQuery = '';
                                          _isSearching = false;
                                        });
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
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: AppColors.secondary),
                    tooltip: 'Close history',
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),

            // New Chat Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      ref.read(chatControllerProvider.notifier).startNewChat();
                      context.pop();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/new_chat.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                              AppColors.background,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'New Chat',
                            style: GoogleFonts.inter(
                              color: AppColors.background,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Chats List
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
                              color: AppColors.secondary.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _searchQuery.isEmpty
                  ? _buildCategorizedList()
                  : _buildSearchResults(),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(
                      AppColors.primary,
                      BlendMode.srcIn,
                    ),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Settings coming soon',
                            style: GoogleFonts.inter(
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.monitorSmartphone,
                      color: AppColors.secondary,
                    ),
                    tooltip: 'Open Connection Setup',
                    onPressed: () => context.push(AppRoutes.config),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _categorizedChats.length,
      itemBuilder: (context, index) {
        final category = _categorizedChats.keys.elementAt(index);
        final chats = _categorizedChats[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8, bottom: 12),
              child: Text(
                category,
                style: GoogleFonts.inter(
                  color: AppColors.secondary.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
            ),
            ...chats.map(
              (chat) => _buildHistoryItem(
                context,
                chat['title']!,
                chat['time']!,
                index == 0 && chats.indexOf(chat) == 0, // First item active
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final allChats = _categorizedChats.values
        .expand((chats) => chats)
        .where((chat) => chat['title']!.toLowerCase().contains(_searchQuery))
        .toList();

    if (allChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.searchX,
              size: 48,
              color: AppColors.secondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No chats found',
              style: GoogleFonts.inter(
                color: AppColors.secondary.withOpacity(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: GoogleFonts.inter(
                color: AppColors.secondary.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: allChats.length,
      itemBuilder: (context, index) {
        final chat = allChats[index];
        return _buildHistoryItem(context, chat['title']!, chat['time']!, false);
      },
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    String title,
    String time,
    bool isActive,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.surface
            : AppColors.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5)
            : Border.all(
                color: AppColors.secondary.withOpacity(0.05),
                width: 1,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // TODO: Load this chat session
            context.pop();
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.secondary,
                          fontSize: 15,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          color: AppColors.secondary.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    LucideIcons.moreVertical,
                    size: 18,
                    color: AppColors.secondary.withOpacity(0.5),
                  ),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.secondary.withOpacity(0.1),
                    ),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.edit2,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Rename',
                            style: GoogleFonts.inter(
                              color: AppColors.secondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.trash2,
                            size: 16,
                            color: Colors.red.withOpacity(0.8),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: GoogleFonts.inter(
                              color: Colors.red.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      // TODO: Implement delete functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Chat deleted',
                            style: GoogleFonts.inter(),
                          ),
                          backgroundColor: AppColors.surface,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    } else if (value == 'rename') {
                      // TODO: Implement rename functionality
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
