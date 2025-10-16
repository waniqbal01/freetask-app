import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/chat/chat_bloc.dart';
import '../../controllers/chat/chat_event.dart';
import '../../controllers/chat/chat_state.dart';
import '../../models/chat.dart';
import '../../models/message.dart';
import '../../models/message_attachment.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.participantIds,
    this.thread,
  });

  final String chatId;
  final List<String> participantIds;
  final ChatThread? thread;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<_AttachmentDraft> _attachments = [];
  final FocusNode _inputFocusNode = FocusNode();
  int _lastMessageCount = 0;
  bool _isTyping = false;

  String _initials(String value) {
    if (value.isEmpty) return 'FT';
    final trimmed = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (trimmed.isEmpty) return 'FT';
    final normalized = trimmed.length <= 2
        ? trimmed
        : trimmed.substring(0, 2);
    return normalized.toUpperCase();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 80);
    if (!mounted || files == null) return;
    setState(() {
      for (final file in files) {
        final draft = _AttachmentDraft.fromXFile(file);
        if (!_attachments.any((item) => item.file.path == draft.file.path)) {
          _attachments.add(draft);
        }
      }
    });
  }

  Future<void> _pickFromCamera() async {
    final photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (!mounted || photo == null) return;
    setState(() {
      final draft = _AttachmentDraft.fromXFile(photo);
      if (!_attachments.any((item) => item.file.path == draft.file.path)) {
        _attachments.add(draft);
      }
    });
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (!mounted || result == null) return;
    setState(() {
      for (final file in result.files) {
        if (file.path == null) continue;
        final draft = _AttachmentDraft.fromPath(file.path!, file.name);
        if (!_attachments.any((item) => item.file.path == draft.file.path)) {
          _attachments.add(draft);
        }
      }
    });
  }

  void _removeAttachment(_AttachmentDraft draft) {
    setState(() => _attachments.remove(draft));
  }

  void _onTextChanged(String value) {
    final bloc = context.read<ChatBloc>();
    final trimmed = value.trim();
    final isTyping = trimmed.isNotEmpty;
    if (isTyping != _isTyping) {
      _isTyping = isTyping;
      bloc.add(TypingStatusRequested(isTyping));
    }
    if (!isTyping) {
      bloc.add(const TypingStatusRequested(false));
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    final attachments = _attachments.map((draft) => draft.file).toList();
    if (text.isEmpty && attachments.isEmpty) {
      return;
    }
    final bloc = context.read<ChatBloc>();
    bloc.add(SendMessageRequested(text: text, attachments: attachments));
    bloc.add(const TypingStatusRequested(false));
    _messageController.clear();
    _isTyping = false;
    setState(() => _attachments.clear());
    _inputFocusNode.requestFocus();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.select<AuthBloc, AuthState>((bloc) => bloc.state);
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';

    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.messages.length != current.messages.length,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        if (state.messages.length != _lastMessageCount) {
          _lastMessageCount = state.messages.length;
          _scrollToBottom();
        }
      },
      builder: (context, state) {
        final isOnline = state.onlineUserIds.values.any((status) => status);
        final displayId = widget.thread?.id ?? widget.chatId;
        final avatarLabel = _initials(displayId);
        final onlineLabel = state.isSomeoneTyping
            ? 'Typing…'
            : isOnline
                ? 'Online'
                : 'Offline';
        final showOfflineBanner = !state.isConnected;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(child: Text(avatarLabel)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayId,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        onlineLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: state.isSomeoneTyping
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context
                      .read<ChatBloc>()
                      .add(ChatStarted(chatId: widget.chatId, participantIds: widget.participantIds));
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (showOfflineBanner)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Offline mode: messages will send automatically when you reconnect.'),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<ChatBloc>().add(const RetryPendingMessages());
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state.isLoading && state.messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state.messages.isEmpty && state.cachedLastMessage != null) {
                      return ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(24),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Last message (cached)',
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(state.cachedLastMessage!.text),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      DateFormat('hh:mm a').format(state.cachedLastMessage!.createdAt.toLocal()),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Center(child: Text('No live messages yet. Start the conversation!')),
                        ],
                      );
                    }

                    if (state.messages.isEmpty) {
                      return const Center(child: Text('Say hello to start chatting.'));
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        final isMine = message.senderId == currentUserId;
                        final previousSender =
                            index > 0 ? state.messages[index - 1].senderId : null;
                        final showAvatar = !isMine && previousSender != message.senderId;
                        return _MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          isMine: isMine,
                          showAvatar: showAvatar,
                          avatarLabel: showAvatar ? _initials(message.senderId) : '',
                          onRetry: isMine && message.status == MessageDeliveryStatus.failed
                              ? () => context
                                  .read<ChatBloc>()
                                  .add(const RetryPendingMessages())
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_attachments.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                    border: const Border(
                      top: BorderSide(width: 0.2),
                    ),
                  ),
                  child: SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final attachment = _attachments[index];
                        return _AttachmentPreview(
                          draft: attachment,
                          onRemove: () => _removeAttachment(attachment),
                        );
                      },
                    ),
                  ),
                ),
              if (state.isSomeoneTyping)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Typing…',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _AttachmentButton(
                        icon: Icons.photo_outlined,
                        tooltip: 'Gallery',
                        onPressed: _pickFromGallery,
                      ),
                      _AttachmentButton(
                        icon: Icons.camera_alt_outlined,
                        tooltip: 'Camera',
                        onPressed: _pickFromCamera,
                      ),
                      _AttachmentButton(
                        icon: Icons.attach_file,
                        tooltip: 'Document',
                        onPressed: _pickDocument,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _inputFocusNode,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.send,
                          onChanged: _onTextChanged,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Type a message…',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _sendMessage,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          shape: const CircleBorder(),
                        ),
                        child: const Icon(Icons.send_rounded),
                      ),
                    ],
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

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

class _AttachmentDraft {
  _AttachmentDraft({required this.file, required this.mimeType, required this.name});

  factory _AttachmentDraft.fromXFile(XFile file) {
    final mimeType = file.mimeType ?? lookupMimeType(file.path) ?? 'application/octet-stream';
    return _AttachmentDraft(
      file: File(file.path),
      mimeType: mimeType,
      name: file.name,
    );
  }

  factory _AttachmentDraft.fromPath(String path, String? name) {
    return _AttachmentDraft(
      file: File(path),
      mimeType: lookupMimeType(path) ?? 'application/octet-stream',
      name: name ?? path.split('/').last,
    );
  }

  final File file;
  final String mimeType;
  final String name;

  bool get isImage => mimeType.startsWith('image/');

  bool get isVideo => mimeType.startsWith('video/');
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.draft, required this.onRemove});

  final _AttachmentDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 100,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Theme.of(context).colorScheme.surfaceVariant,
          ),
          clipBehavior: Clip.antiAlias,
          child: draft.isImage
              ? Image.file(
                  draft.file,
                  fit: BoxFit.cover,
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        draft.isVideo ? Icons.videocam_outlined : Icons.insert_drive_file_outlined,
                        size: 28,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          draft.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton.filled(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.showAvatar,
    required this.avatarLabel,
    this.onRetry,
  });

  final Message message;
  final bool isMine;
  final bool showAvatar;
  final String avatarLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = isMine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceVariant.withOpacity(0.9);
    final textColor = isMine ? Colors.white : theme.colorScheme.onSurface;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMine ? 20 : 6),
      bottomRight: Radius.circular(isMine ? 6 : 20),
    );

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (message.attachments.isNotEmpty)
            ...message.attachments.map((attachment) => _AttachmentContent(
                  attachment: attachment,
                  isMine: isMine,
                )),
          if (message.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: message.attachments.isEmpty ? 0 : 8),
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(
                DateFormat('hh:mm a').format(message.createdAt.toLocal()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withOpacity(0.8),
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 6),
                _StatusIcon(status: message.status),
              ],
              if (!isMine && message.status == MessageDeliveryStatus.read)
                const SizedBox(width: 18),
            ],
          ),
          if (isMine && message.status == MessageDeliveryStatus.failed && onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Tap to retry'),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: showAvatar
                  ? CircleAvatar(
                      key: ValueKey(message.senderId),
                      radius: 16,
                      child: Text(
                        avatarLabel,
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    )
                  : const SizedBox(width: 32),
            ),
          if (!isMine) const SizedBox(width: 8),
          Flexible(child: bubble),
          if (isMine) const SizedBox(width: 8),
          if (isMine)
            const SizedBox(
              width: 32,
            ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageDeliveryStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case MessageDeliveryStatus.sent:
        return const Icon(Icons.check, size: 16);
      case MessageDeliveryStatus.delivered:
        return const Icon(Icons.done_all, size: 16);
      case MessageDeliveryStatus.read:
        return Icon(
          Icons.done_all,
          size: 16,
          color: Theme.of(context).colorScheme.secondary,
        );
      case MessageDeliveryStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 16,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }
}

class _AttachmentContent extends StatelessWidget {
  const _AttachmentContent({required this.attachment, required this.isMine});

  final MessageAttachment attachment;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);
    final hasLocalFile = attachment.isLocal;
    final file = hasLocalFile ? File(attachment.localPath!) : null;

    if (attachment.isImage) {
      final imageWidget = hasLocalFile
          ? Image.file(
              file!,
              fit: BoxFit.cover,
              height: 180,
              width: 180,
            )
          : Image.network(
              attachment.url,
              fit: BoxFit.cover,
              height: 180,
              width: 180,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                width: 180,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image),
              ),
            );
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: radius,
          child: imageWidget,
        ),
      );
    }

    final icon = attachment.isVideo
        ? Icons.videocam_outlined
        : Icons.insert_drive_file_outlined;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: !hasLocalFile && attachment.url.isNotEmpty
            ? () => _launchUrl(attachment.url)
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isMine
                    ? theme.colorScheme.onPrimary.withOpacity(0.1)
                    : theme.colorScheme.surface)
                .withOpacity(0.9),
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  attachment.name.isNotEmpty
                      ? attachment.name
                      : attachment.url.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!hasLocalFile && attachment.url.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.open_in_new, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
