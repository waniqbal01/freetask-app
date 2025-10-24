import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/chat/chat_bloc.dart';
import '../../controllers/chat/chat_event.dart';
import '../../controllers/chat/chat_list_bloc.dart';
import '../../controllers/chat/chat_list_event.dart';
import '../../controllers/chat/chat_list_state.dart';
import '../../controllers/chat/chat_state.dart';
import '../../models/chat.dart';
import '../../services/chat_cache_service.dart';
import '../../services/chat_service.dart';
import '../../services/socket_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/chat_bubble.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  static const routeName = AppRoutes.chat;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
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
        if (state.errorMessage != null && threads.isEmpty) {
          return _ChatListStateMessage(
            icon: Icons.error_outline,
            title: 'Unable to load conversations',
            message: state.errorMessage!,
            actionLabel: 'Retry',
            onAction: () => context
                .read<ChatListBloc>()
                .add(const LoadChatThreads()),
          );
        }
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
                      ? const _ChatListStateMessage(
                          icon: Icons.chat_bubble_outline,
                          title: 'No conversations yet',
                          message:
                              'Start a chat from a job or invite someone to collaborate.',
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
                                    theme.colorScheme.primary
                                        .withValues(alpha: 0.12),
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
              if (state.errorMessage != null && threads.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
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

class _ChatListStateMessage extends StatelessWidget {
  const _ChatListStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatRoomStateMessage extends StatelessWidget {
  const _ChatRoomStateMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: icon == Icons.error_outline
                    ? theme.colorScheme.error
                    : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
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
  final List<File> _attachments = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    context.read<ChatBloc>().add(
          SendMessageRequested(
            text: text,
            attachments: List<File>.from(_attachments),
          ),
        );
    _messageController.clear();
    _attachments.clear();
    context.read<ChatBloc>().add(const TypingStatusRequested(false));
    setState(() {});
  }

  void _removeAttachment(File file) {
    setState(() {
      _attachments.remove(file);
    });
  }

  Future<void> _pickAttachment() async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Attach file'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter file path',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Attach'),
            ),
          ],
        );
      },
    );
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found.')), 
      );
      return;
    }
    final size = file.lengthSync();
    const maxSize = 10 * 1024 * 1024;
    if (size > maxSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachments must be 10MB or smaller.')),
      );
      return;
    }
    setState(() {
      _attachments.add(file);
    });
  }

  bool _isPartnerOnline(ChatState state) {
    final others = state.participantIds.where((id) => id != widget.currentUserId);
    for (final id in others) {
      if (state.isUserOnline(id)) return true;
    }
    return false;
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
          title: BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              final online = _isPartnerOnline(state);
              final typing = state.isSomeoneTyping;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chat ${widget.thread.id.substring(0, widget.thread.id.length > 8 ? 8 : widget.thread.id.length)}'),
                  const SizedBox(height: 2),
                  Text(
                    typing
                        ? 'Typing…'
                        : online
                            ? 'Online'
                            : 'Offline',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: typing
                              ? Colors.orange
                              : online
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                  ),
                ],
              );
            },
          ),
        ),
        body: Column(
          children: [
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (!state.isSomeoneTyping) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Typing…',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  final messages = state.messages;
                  if (state.isLoading && messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.errorMessage != null && messages.isEmpty) {
                    return _ChatRoomStateMessage(
                      icon: Icons.error_outline,
                      message: state.errorMessage!,
                      onRetry: () => context.read<ChatBloc>().add(
                            ChatStarted(
                              chatId: widget.thread.id,
                              participantIds: widget.thread.participants,
                            ),
                          ),
                    );
                  }
                  if (messages.isEmpty) {
                    return const _ChatRoomStateMessage(
                      icon: Icons.chat_bubble_outline,
                      message: 'Say hello to start the conversation.',
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
            if (_attachments.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachments
                      .map(
                        (file) => Chip(
                          label: Text(file.uri.pathSegments.isNotEmpty
                              ? file.uri.pathSegments.last
                              : file.path),
                          deleteIcon: const Icon(Icons.close),
                          onDeleted: () => _removeAttachment(file),
                        ),
                      )
                      .toList(),
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
                            color: Colors.black.withValues(alpha: 0.05),
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
                        onChanged: (value) => context
                            .read<ChatBloc>()
                            .add(TypingStatusRequested(value.isNotEmpty)),
                        onEditingComplete: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _pickAttachment,
                    icon: const Icon(Icons.attach_file),
                  ),
                  const SizedBox(width: 4),
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
