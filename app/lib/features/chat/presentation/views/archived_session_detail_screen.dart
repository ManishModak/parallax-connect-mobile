import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/services/storage/chat_archive_storage.dart';
import '../../../../app/constants/app_colors.dart';

class ArchivedSessionDetailScreen extends StatelessWidget {
  final ChatSession session;

  const ArchivedSessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Archived Session',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(session.timestamp),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Session title header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.messageCount} messages',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          // Messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: session.messages.length,
              itemBuilder: (context, index) {
                final message = session.messages[index];
                final isUser = message['isUser'] as bool;
                final text = message['text'] as String;
                final timestamp = DateTime.parse(
                  message['timestamp'] as String,
                );

                return _buildMessageBubble(
                  context,
                  text: text,
                  isUser: isUser,
                  timestamp: timestamp,
                );
              },
            ),
          ),
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 16, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is a read-only archived session',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context, {
    required String text,
    required bool isUser,
    required DateTime timestamp,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.brand : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: isUser
                  ? Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    )
                  : MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                        code: TextStyle(
                          backgroundColor: AppColors.background,
                          color: AppColors.accent,
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(timestamp),
              style: const TextStyle(fontSize: 11, color: AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
