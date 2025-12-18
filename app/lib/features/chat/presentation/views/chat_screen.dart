import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../app/constants/app_colors.dart';
import '../../../../app/routes/app_router.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../settings/presentation/view_models/settings_controller.dart';
import '../view_models/chat_controller.dart';
import '../state/chat_state.dart';
import '../widgets/messages/chat_message_bubble.dart';
import '../widgets/chat_input_area.dart';
import '../widgets/messages/streaming_message_bubble.dart';
import '../widgets/indicators/collapsible_thinking_indicator.dart';
import '../widgets/indicators/searching_indicator.dart';
import '../widgets/app_bar_model_selector.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  double _dragStartX = 0.0;
  double _dragCurrentX = 0.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-scroll to bottom when new messages arrive or streaming content updates.
    // Must be in build() because ref is not available in initState for ConsumerStatefulWidget.
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      final hasNewMessage =
          next.messages.length > (previous?.messages.length ?? 0);
      final isStreaming = next.isStreaming;
      final contentChanged =
          next.streamingContent != (previous?.streamingContent ?? '');
      final thinkingChanged =
          next.thinkingContent != (previous?.thinkingContent ?? '');

      if (hasNewMessage ||
          (isStreaming && (contentChanged || thinkingChanged))) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    final chatState = ref.watch(chatControllerProvider);
    final chatController = ref.read(chatControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'History',
          icon: Icon(
            LucideIcons.panelLeftOpen,
            color: AppColors.secondary,
            size: 28,
          ),
          onPressed: () {
            ref.read(hapticsHelperProvider).triggerHaptics();
            context.push(AppRoutes.history);
          },
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Parallax Connect',
              style: GoogleFonts.inter(color: AppColors.primary, fontSize: 16),
            ),
            const SizedBox(height: 2),
            const AppBarModelSelector(),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              // Show private chat icon when no messages and not in private mode
              // Show active private chat icon when in private mode
              // Show new chat icon otherwise
              chatState.messages.isEmpty && !chatState.isPrivateMode
                  ? 'assets/icons/private_chat.svg'
                  : chatState.isPrivateMode
                  ? 'assets/icons/private_chat_active.svg'
                  : 'assets/icons/new_chat.svg',
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                AppColors.secondary,
                BlendMode.srcIn,
              ),
            ),
            tooltip: chatState.messages.isEmpty && !chatState.isPrivateMode
                ? 'Start Private Chat'
                : chatState.isPrivateMode
                    ? 'Exit Private & Start New'
                    : 'Start New Chat',
            onPressed: () {
              ref.read(hapticsHelperProvider).triggerHaptics();
              if (chatState.messages.isEmpty && !chatState.isPrivateMode) {
                chatController.togglePrivateMode();
              } else if (chatState.isPrivateMode) {
                chatController.startNewChat();
              } else {
                chatController.startNewChat();
              }
            },
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          _dragStartX = details.localPosition.dx;
          _dragCurrentX = _dragStartX;
        },
        onHorizontalDragUpdate: (details) {
          _dragCurrentX = details.localPosition.dx;
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0.0;
          final distance = _dragCurrentX - _dragStartX;
          final screenWidth = MediaQuery.of(context).size.width;
          final distanceThreshold = screenWidth * 0.15;
          const velocityThreshold = 200.0;

          // Swipe Right (Velocity > 0 OR Distance > Threshold) -> Open History OR Exit Private Mode
          if (velocity > velocityThreshold || distance > distanceThreshold) {
            ref.read(hapticsHelperProvider).triggerHaptics();
            if (chatState.isPrivateMode) {
              // Exit private mode first
              chatController.disablePrivateMode();
            } else {
              // Open history screen
              context.push(AppRoutes.history);
            }
          }
          // Swipe Left (Velocity < 0 OR Distance < -Threshold) -> Enable Private Mode
          else if (velocity < -velocityThreshold ||
              distance < -distanceThreshold) {
            if (!chatState.isPrivateMode) {
              ref.read(hapticsHelperProvider).triggerHaptics();
              chatController.togglePrivateMode();
            }
          }
        },
        child: Column(
          children: [
            Expanded(
              child: chatState.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (chatState.isPrivateMode) ...[
                            // Private chat empty state
                            SvgPicture.asset(
                              'assets/icons/private_chat.svg',
                              width: 64,
                              height: 64,
                              colorFilter: ColorFilter.mode(
                                AppColors.secondary,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Private Chat',
                              style: GoogleFonts.inter(
                                color: AppColors.primaryMildVariant,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Text(
                                'This chat won\'t appear in history and will be fully erased',
                                style: GoogleFonts.inter(
                                  color: AppColors.secondary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ] else ...[
                            // Normal empty state
                            const Icon(
                              LucideIcons.command,
                              size: 64,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Normal Chat',
                              style: GoogleFonts.inter(
                                color: AppColors.primaryMildVariant,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Text(
                                'Conversations are automatically saved to your history',
                                style: GoogleFonts.inter(
                                  color: AppColors.secondary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              // Retrace Logic:
                              // If editing, only show messages before the one being edited.
                              // The edited message itself is in the input area.
                              if (chatState.editingMessage != null) {
                                final editingIndex = chatState.messages.indexOf(
                                  chatState.editingMessage!,
                                );
                                if (editingIndex != -1 &&
                                    index >= editingIndex) {
                                  return const SizedBox.shrink();
                                }
                              }

                              final message = chatState.messages[index];
                              return ChatMessageBubble(
                                message: message,
                                onRetry: () {
                                  ref
                                      .read(hapticsHelperProvider)
                                      .triggerHaptics();
                                  chatController.retryMessage(message);
                                },
                                onEdit: () {
                                  ref
                                      .read(hapticsHelperProvider)
                                      .triggerHaptics();
                                  chatController.startEditing(message);
                                },
                              );
                            }, childCount: chatState.messages.length),
                          ),
                        ),
                        // Show searching indicator (Only when actually searching)
                        if (chatState.isSearchingWeb)
                          SliverToBoxAdapter(
                            child: SearchingIndicator(
                              statusMessage: chatState.searchStatusMessage,
                              isSearching: true,
                            ),
                          ),

                        // Show analyzing indicator (Minimal style)
                        if (chatState.isAnalyzingIntent)
                          SliverToBoxAdapter(
                            child: SearchingIndicator(
                              statusMessage:
                                  chatState.searchStatusMessage.isNotEmpty
                                  ? chatState.searchStatusMessage
                                  : 'Analyzing intent...',
                              isSearching: true, // Triggers the pulse animation
                            ),
                          ),

                        // Show thinking indicator (Only for actual generation/thinking content)
                        if (chatState.isStreaming &&
                            chatState.isThinking &&
                            !chatState.isSearchingWeb &&
                            !chatState.isAnalyzingIntent)
                          SliverToBoxAdapter(
                            child: Builder(
                              builder: (context) {
                                final showThinking = ref.watch(
                                  settingsControllerProvider.select(
                                    (s) => s.showThinking,
                                  ),
                                );
                                if (!showThinking) {
                                  return const SizedBox.shrink();
                                }

                                return CollapsibleThinkingIndicator(
                                  thinkingContent: chatState.thinkingContent,
                                );
                              },
                            ),
                          ),
                        // Show streaming content
                        if (chatState.isStreaming &&
                            chatState.streamingContent.isNotEmpty)
                          SliverToBoxAdapter(
                            child: StreamingMessageBubble(
                              content: chatState.streamingContent,
                              isComplete: false,
                            ),
                          ),
                      ],
                    ),
            ),
            if (chatState.error != null)
              Container(
                padding: const EdgeInsets.all(4),
                color: AppColors.error.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatState.error!,
                        style: GoogleFonts.inter(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ChatInputArea(
              isLoading: chatState.isLoading,
              onSubmitted: (text, attachmentPaths) {
                ref
                    .read(chatControllerProvider.notifier)
                    .sendMessage(text, attachmentPaths: attachmentPaths);
              },
              onCameraTap: () async {
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                );
                return image?.path;
              },
              onGalleryTap: () async {
                final picker = ImagePicker();
                final List<XFile> images = await picker.pickMultiImage();
                return images.map((img) => img.path).toList();
              },
              onFileTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  allowMultiple: true,
                );
                if (result != null) {
                  return result.files
                      .where((file) => file.path != null)
                      .map((file) => file.path!)
                      .toList();
                }
                return [];
              },
            ),
          ],
        ),
      ),
    );
  }
}
