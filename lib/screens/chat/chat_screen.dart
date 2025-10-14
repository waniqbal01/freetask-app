import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/chat/chat_detail_bloc.dart';
import '../../controllers/chat/chat_detail_event.dart';
import '../../controllers/chat/chat_detail_state.dart';
import '../../models/message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  File? _pendingImage;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    context.read<ChatDetailBloc>().add(LoadChatMessages(widget.chatId));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _pendingImage = File(file.path));
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingImage == null) {
      return;
    }
    context.read<ChatDetailBloc>().add(
          SendChatMessage(
            chatId: widget.chatId,
            text: text,
            image: _pendingImage,
          ),
        );
    _messageController.clear();
    setState(() => _pendingImage = null);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthBloc, AuthState>((bloc) => bloc.state);
    final userId = user is AuthAuthenticated ? user.user.id : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: BlocListener<ChatDetailBloc, ChatDetailState>(
        listenWhen: (previous, current) =>
            previous.messages.length != current.messages.length ||
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
          if (state.messages.length > _lastMessageCount) {
            _scrollToBottom();
          }
          _lastMessageCount = state.messages.length;
        },
        child: BlocBuilder<ChatDetailBloc, ChatDetailState>(
          builder: (context, state) {
            if (state.isLoading && state.messages.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final messages = state.messages;

            return Column(
              children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == userId;
                    return _MessageBubble(message: message, isMine: isMine);
                  },
                ),
              ),
              if (_pendingImage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _pendingImage!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 16,
                          child: IconButton(
                            onPressed: () => setState(() => _pendingImage = null),
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image_outlined),
                        onPressed: _pickImage,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed:
                            state.isSending ? null : _sendMessage,
                        icon: state.isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceVariant;
    final textColor = isMine ? Colors.white : null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: Radius.circular(isMine ? 0 : 16),
            bottomLeft: Radius.circular(isMine ? 16 : 0),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.attachments.isNotEmpty)
              ...message.attachments.map(
                (attachment) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      attachment,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black12,
                        height: 150,
                        width: 200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: textColor),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: textColor?.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final time = TimeOfDay.fromDateTime(local);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
