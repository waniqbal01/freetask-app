import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../models/message.dart';
import '../../models/message_attachment.dart';
import '../../models/pending_message.dart';
import '../../services/chat_cache_service.dart';
import '../../services/chat_service.dart';
import '../../services/socket_service.dart';
import '../../utils/logger.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(
    this._chatService,
    this._socketService,
    this._cacheService, {
    required String currentUserId,
  })  : _currentUserId = currentUserId,
        super(const ChatState()) {
    on<ChatStarted>(_onChatStarted);
    on<SendMessageRequested>(_onSendMessageRequested);
    on<MessageReceived>(_onMessageReceived);
    on<MessageStatusReceived>(_onMessageStatusReceived);
    on<TypingStatusReceived>(_onTypingStatusReceived);
    on<PresenceStatusReceived>(_onPresenceStatusReceived);
    on<TypingStatusRequested>(_onTypingStatusRequested);
    on<RetryPendingMessages>(_onRetryPendingMessages);
    on<OutgoingMessageUpdated>(_onOutgoingMessageUpdated);
    on<ChatConnectionChanged>(_onChatConnectionChanged);
    on<ReadReceiptRequested>(_onReadReceiptRequested);
    on<PendingQueueLoaded>(_onPendingQueueLoaded);
  }

  final ChatService _chatService;
  final SocketService _socketService;
  final ChatCacheService _cacheService;
  final String _currentUserId;
  final _uuid = const Uuid();

  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<TypingEvent>? _typingSubscription;
  StreamSubscription<UserPresenceEvent>? _presenceSubscription;
  StreamSubscription<MessageStatusUpdate>? _statusSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _typingTimer;
  bool _isTyping = false;

  Future<void> _onChatStarted(ChatStarted event, Emitter<ChatState> emit) async {
    if (state.chatId != null && state.chatId != event.chatId) {
      _socketService.leaveChatRoom(state.chatId!);
    }

    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _presenceSubscription?.cancel();
    _statusSubscription?.cancel();

    final cachedLastMessage = _cacheService.getCachedLastMessage(event.chatId);
    final pending = _cacheService.getPendingMessages(event.chatId);

    emit(
      state.copyWith(
        chatId: event.chatId,
        participantIds: event.participantIds,
        isLoading: true,
        pendingMessages: pending,
        cachedLastMessage: cachedLastMessage ?? state.cachedLastMessage,
        typingUserIds: <String>{},
        onlineUserIds: <String, bool>{},
        clearError: true,
      ),
    );

    _socketService.joinChatRoom(event.chatId);

    _messageSubscription = _socketService.messages.listen((message) {
      if (message.chatId == event.chatId) {
        add(MessageReceived(message));
      }
    });

    _typingSubscription = _socketService.typing.listen((typingEvent) {
      if (typingEvent.chatId == event.chatId &&
          typingEvent.userId != _currentUserId) {
        add(TypingStatusReceived(typingEvent));
      }
    });

    _presenceSubscription = _socketService.presence.listen((presenceEvent) {
      if (event.participantIds.contains(presenceEvent.userId)) {
        add(PresenceStatusReceived(presenceEvent));
      }
    });

    _statusSubscription = _socketService.messageStatuses.listen((statusEvent) {
      if (statusEvent.chatId == event.chatId) {
        add(MessageStatusReceived(statusEvent));
      }
    });

    _connectionSubscription ??=
        _socketService.connection.listen((connected) {
      add(ChatConnectionChanged(connected));
    });

    if (pending.isNotEmpty) {
      add(PendingQueueLoaded(pending));
    }

    try {
      final messages = await _chatService.fetchMessages(event.chatId);
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      emit(
        state.copyWith(
          messages: messages,
          cachedLastMessage:
              messages.isNotEmpty ? messages.last : state.cachedLastMessage,
          isLoading: false,
        ),
      );
      if (messages.isNotEmpty) {
        await _cacheService.cacheLastMessage(event.chatId, messages.last);
      }
      final unreadMessageIds = messages
          .where((message) =>
              message.senderId != _currentUserId && !message.hasBeenRead)
          .map((message) => message.id)
          .toList();
      if (unreadMessageIds.isNotEmpty) {
        add(ReadReceiptRequested(unreadMessageIds));
      }
    } on ChatException catch (error, stackTrace) {
      appLog('Failed to load messages', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error when loading messages',
          error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load messages.',
        ),
      );
    }

    if (pending.isNotEmpty) {
      add(const RetryPendingMessages());
    }
  }

  Future<void> _onSendMessageRequested(
    SendMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatId = state.chatId;
    if (chatId == null) {
      return;
    }

    final trimmedText = event.text.trim();
    if (trimmedText.isEmpty && event.attachments.isEmpty) {
      return;
    }

    final localId = _uuid.v4();
    final now = DateTime.now();
    final attachments = event.attachments
        .where((file) => file.path.isNotEmpty)
        .map(
          (file) => PendingAttachment(
            path: file.path,
            name: p.basename(file.path),
            mimeType: lookupMimeType(file.path) ?? 'application/octet-stream',
            size: file.existsSync() ? file.lengthSync() : 0,
          ),
        )
        .toList();
    final pendingMessage = PendingMessage(
      localId: localId,
      chatId: chatId,
      text: trimmedText,
      attachments: attachments,
      createdAt: now,
    );

    final pendingMessages = [...state.pendingMessages, pendingMessage];
    final localMessages = [...state.messages, _fromPending(pendingMessage)];
    localMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    emit(
      state.copyWith(
        pendingMessages: pendingMessages,
        messages: localMessages,
        cachedLastMessage:
            localMessages.isNotEmpty ? localMessages.last : state.cachedLastMessage,
        isSending: false,
      ),
    );

    await _cacheService.savePendingMessages(chatId, pendingMessages);
    if (localMessages.isNotEmpty) {
      await _cacheService.cacheLastMessage(chatId, localMessages.last);
    }

    unawaited(_processPendingMessage(pendingMessage));
  }

  Future<void> _processPendingMessage(PendingMessage pendingMessage) async {
    if (!state.isConnected) {
      return;
    }
    try {
      final files = pendingMessage.attachments
          .map((attachment) => File(attachment.path))
          .where((file) => file.existsSync())
          .toList();
      final sentMessage = await _chatService.sendMessage(
        chatId: pendingMessage.chatId,
        text: pendingMessage.text,
        attachments: files,
      );
      add(
        OutgoingMessageUpdated(
          localId: pendingMessage.localId,
          status: MessageDeliveryStatus.sent,
          remoteMessage: sentMessage,
        ),
      );
    } on ChatException catch (error, stackTrace) {
      appLog('Failed to send message', error: error, stackTrace: stackTrace);
      add(
        OutgoingMessageUpdated(
          localId: pendingMessage.localId,
          status: MessageDeliveryStatus.failed,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error while sending message',
          error: error, stackTrace: stackTrace);
      add(
        OutgoingMessageUpdated(
          localId: pendingMessage.localId,
          status: MessageDeliveryStatus.failed,
          errorMessage: 'Unable to send message.',
        ),
      );
    }
  }

  Future<void> _onMessageReceived(
    MessageReceived event,
    Emitter<ChatState> emit,
  ) async {
    if (state.chatId != event.message.chatId) {
      return;
    }

    final messages = [...state.messages];
    final index = messages.indexWhere((message) => message.id == event.message.id);
    if (index >= 0) {
      messages[index] = event.message;
    } else {
      messages.add(event.message);
    }
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    emit(
      state.copyWith(
        messages: messages,
        cachedLastMessage: messages.isNotEmpty ? messages.last : state.cachedLastMessage,
      ),
    );

    final chatId = state.chatId;
    if (chatId != null) {
      await _cacheService.cacheLastMessage(chatId, messages.last);
    }

    if (event.message.senderId != _currentUserId && !event.message.hasBeenRead) {
      add(ReadReceiptRequested([event.message.id]));
    }
  }

  void _onMessageStatusReceived(
    MessageStatusReceived event,
    Emitter<ChatState> emit,
  ) {
    final messages = [...state.messages];
    final index = messages.indexWhere((message) => message.id == event.update.messageId);
    if (index == -1) {
      return;
    }
    final current = messages[index];
    final updated = current.copyWith(
      status: event.update.status,
      deliveredAt: event.update.deliveredAt ?? current.deliveredAt,
      readAt: event.update.readAt ?? current.readAt,
    );
    messages[index] = updated;
    emit(
      state.copyWith(
        messages: messages,
        cachedLastMessage: messages.isNotEmpty ? messages.last : state.cachedLastMessage,
      ),
    );
  }

  void _onTypingStatusReceived(
    TypingStatusReceived event,
    Emitter<ChatState> emit,
  ) {
    final typingUsers = {...state.typingUserIds};
    if (event.event.isTyping) {
      typingUsers.add(event.event.userId);
    } else {
      typingUsers.remove(event.event.userId);
    }
    emit(state.copyWith(typingUserIds: typingUsers));
  }

  void _onPresenceStatusReceived(
    PresenceStatusReceived event,
    Emitter<ChatState> emit,
  ) {
    final onlineUsers = {...state.onlineUserIds};
    onlineUsers[event.event.userId] = event.event.isOnline;
    emit(state.copyWith(onlineUserIds: onlineUsers));
  }

  Future<void> _onTypingStatusRequested(
    TypingStatusRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatId = state.chatId;
    if (chatId == null) {
      return;
    }
    if (event.isTyping) {
      if (!_isTyping) {
        _socketService.sendTyping(chatId: chatId, isTyping: true);
      }
      _isTyping = true;
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _isTyping = false;
        _socketService.sendTyping(chatId: chatId, isTyping: false);
      });
    } else {
      if (_isTyping) {
        _socketService.sendTyping(chatId: chatId, isTyping: false);
      }
      _isTyping = false;
      _typingTimer?.cancel();
    }
  }

  Future<void> _onRetryPendingMessages(
    RetryPendingMessages event,
    Emitter<ChatState> emit,
  ) async {
    if (!state.isConnected) {
      return;
    }
    for (final pending in state.pendingMessages) {
      final message = state.messages
          .firstWhere((element) => element.id == pending.localId, orElse: () => _fromPending(pending));
      if (message.status == MessageDeliveryStatus.sending ||
          message.status == MessageDeliveryStatus.failed) {
        unawaited(_processPendingMessage(pending));
      }
    }
  }

  Future<void> _onOutgoingMessageUpdated(
    OutgoingMessageUpdated event,
    Emitter<ChatState> emit,
  ) async {
    final messages = [...state.messages];
    final index = messages.indexWhere((message) => message.id == event.localId);

    if (event.remoteMessage != null) {
      final remote = event.remoteMessage!;
      if (index >= 0) {
        messages[index] = remote.copyWith(status: event.status);
      } else {
        messages.add(remote.copyWith(status: event.status));
      }
    } else if (index >= 0) {
      messages[index] = messages[index].copyWith(status: event.status);
    }
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final pendingMessages = [...state.pendingMessages];
    if (event.status != MessageDeliveryStatus.failed) {
      pendingMessages.removeWhere((pending) => pending.localId == event.localId);
    }

    emit(
      state.copyWith(
        messages: messages,
        pendingMessages: pendingMessages,
        cachedLastMessage:
            messages.isNotEmpty ? messages.last : state.cachedLastMessage,
        errorMessage: event.errorMessage,
      ),
    );

    final chatId = state.chatId;
    if (chatId != null) {
      if (pendingMessages.isEmpty) {
        await _cacheService.clearPendingMessages(chatId);
      } else {
        await _cacheService.savePendingMessages(chatId, pendingMessages);
      }
      if (event.remoteMessage != null) {
        await _cacheService.cacheLastMessage(chatId, event.remoteMessage!);
      }
    }

    if (event.status == MessageDeliveryStatus.failed && event.errorMessage != null) {
      addError(Exception(event.errorMessage));
    }
  }

  Future<void> _onChatConnectionChanged(
    ChatConnectionChanged event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isConnected: event.isConnected));
    if (event.isConnected) {
      add(const RetryPendingMessages());
    }
  }

  Future<void> _onReadReceiptRequested(
    ReadReceiptRequested event,
    Emitter<ChatState> emit,
  ) async {
    final chatId = state.chatId;
    if (chatId == null || event.messageIds.isEmpty) {
      return;
    }
    try {
      await _chatService.markMessagesRead(
        chatId: chatId,
        messageIds: event.messageIds,
      );
    } catch (error, stackTrace) {
      appLog('Failed to mark messages as read', error: error, stackTrace: stackTrace);
    }
    _socketService.sendReadReceipt(chatId: chatId, messageIds: event.messageIds);

    final messages = [...state.messages];
    var updated = false;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (event.messageIds.contains(message.id) &&
          message.status != MessageDeliveryStatus.read) {
        messages[i] = message.copyWith(
          status: MessageDeliveryStatus.read,
          readAt: DateTime.now(),
        );
        updated = true;
      }
    }
    if (updated) {
      emit(
        state.copyWith(
          messages: messages,
          cachedLastMessage:
              messages.isNotEmpty ? messages.last : state.cachedLastMessage,
        ),
      );
    }
  }

  void _onPendingQueueLoaded(
    PendingQueueLoaded event,
    Emitter<ChatState> emit,
  ) {
    final localMessages = [...state.messages];
    for (final pending in event.pendingMessages) {
      final index =
          localMessages.indexWhere((message) => message.id == pending.localId);
      final pendingMessage = _fromPending(pending);
      if (index >= 0) {
        localMessages[index] = pendingMessage;
      } else {
        localMessages.add(pendingMessage);
      }
    }
    localMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    emit(
      state.copyWith(
        pendingMessages: event.pendingMessages,
        messages: localMessages,
        cachedLastMessage:
            localMessages.isNotEmpty ? localMessages.last : state.cachedLastMessage,
      ),
    );
  }

  Message _fromPending(PendingMessage pending) {
    final attachments = pending.attachments
        .map(
          (attachment) => MessageAttachment.local(
            path: attachment.path,
            name: attachment.name,
            mimeType: attachment.mimeType,
            size: attachment.size,
          ),
        )
        .toList();
    return Message(
      id: pending.localId,
      chatId: pending.chatId,
      senderId: _currentUserId,
      text: pending.text,
      attachments: attachments,
      createdAt: pending.createdAt,
      status: MessageDeliveryStatus.sending,
    );
  }

  @override
  Future<void> close() {
    _typingTimer?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _presenceSubscription?.cancel();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    if (state.chatId != null) {
      _socketService.leaveChatRoom(state.chatId!);
    }
    return super.close();
  }
}
