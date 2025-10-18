import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/chat/chat_bloc.dart';
import '../controllers/chat/chat_event.dart';
import '../controllers/chat/chat_list_bloc.dart';
import '../controllers/chat/chat_list_event.dart';
import '../controllers/chat/chat_list_state.dart';
import '../controllers/chat/chat_state.dart';
import '../models/chat.dart';
import '../services/chat_cache_service.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static const routeName = '/chat';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatListBloc>().add(const LoadChatThreads());
    });
  }

  Future<void> _refresh() async {
    context.read<ChatListBloc>().add(const RefreshChatThreads());
  }

  void _openThread(ChatThread thread) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChatRoomPage(thread: thread),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ChatListBloc, ChatListState>(
      builder: (context, state) {
        if (state.isLoading && state.threads.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final threads = state.threads;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Messages',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Continue conversations and stay connected with your collaborators.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: threads.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No conversations yet',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Start a chat from a job or invite someone to collaborate.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final thread = threads[index];
                            final lastMessage = thread.lastMessage;
                            final initials = thread.participants.isNotEmpty
                                ? thread.participants.first.characters.take(2).toString().toUpperCase()
                                : 'FT';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              onTap: () => _openThread(thread),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    theme.colorScheme.primary.withOpacity(0.12),
                                child: Text(
                                  initials,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                'Chat ${thread.id.substring(0, thread.id.length > 6 ? 6 : thread.id.length)}',
                                style: theme.textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                lastMessage?.text ?? 'No messages yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: thread.unreadCount > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        thread.unreadCount.toString(),
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : null,
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemCount: threads.length,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatRoomPage extends StatelessWidget {
  const _ChatRoomPage({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final chatService = RepositoryProvider.of<ChatService>(context);
    final socketService = RepositoryProvider.of<SocketService>(context);
    final cacheService = RepositoryProvider.of<ChatCacheService>(context);
    final storage = RepositoryProvider.of<StorageService>(context);
    final userId = storage.getUser()?.id ?? '';

    return BlocProvider<ChatBloc>(
      create: (_) => ChatBloc(
        chatService,
        socketService,
        cacheService,
        currentUserId: userId,
      )..add(ChatStarted(chatId: thread.id, participantIds: thread.participants)),
      child: _ChatRoomView(
        thread: thread,
        currentUserId: userId,
      ),
    );
  }
}

class _ChatRoomView extends StatefulWidget {
  const _ChatRoomView({required this.thread, required this.currentUserId});

  final ChatThread thread;
  final String currentUserId;

  @override
  State<_ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<_ChatRoomView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(SendMessageRequested(text: text));
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.messages.length != current.messages.length,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chat ${widget.thread.id.substring(0, widget.thread.id.length > 8 ? 8 : widget.thread.id.length)}'),
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  final messages = state.messages;
                  if (state.isLoading && messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'Say hello to start the conversation.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  }
                  final ordered = messages.toList()
                    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemBuilder: (context, index) {
                      final message = ordered[index];
                      final isMine = message.senderId == widget.currentUserId;
                      return ChatBubble(
                        message: message,
                        isMine: isMine,
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: ordered.length,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _sendMessage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Icon(Icons.send_rounded),
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
