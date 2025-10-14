import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/chat/chat_list_bloc.dart';
import '../../controllers/chat/chat_list_event.dart';
import '../../controllers/chat/chat_list_state.dart';
import '../../models/chat.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ChatListBloc>().add(const LoadChatThreads());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatListBloc, ChatListState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading && state.threads.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.threads.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<ChatListBloc>().add(const RefreshChatThreads());
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Icon(Icons.chat_bubble_outline,
                      size: 48, color: Colors.grey),
                ),
                SizedBox(height: 12),
                Center(child: Text('No conversations yet.')),
                SizedBox(height: 120),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<ChatListBloc>().add(const RefreshChatThreads());
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final thread = state.threads[index];
              return _ChatThreadTile(thread: thread);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: state.threads.length,
          ),
        );
      },
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  const _ChatThreadTile({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final lastMessage = thread.lastMessage;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRoutes.chat,
          arguments: thread.id,
        );
      },
      leading: CircleAvatar(
        child: Text(
          (thread.id.length >= 2
                  ? thread.id.substring(0, 2)
                  : thread.id)
              .toUpperCase(),
        ),
      ),
      title: Text(
        'Conversation ${thread.id.length >= 6 ? thread.id.substring(0, 6) : thread.id}',
      ),
      subtitle: Text(
        lastMessage?.text ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: thread.unreadCount > 0
          ? CircleAvatar(
              radius: 12,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                thread.unreadCount.toString(),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            )
          : Text(
              lastMessage != null
                  ? timeAgo(lastMessage.createdAt)
                  : '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
    );
  }

  String timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}
