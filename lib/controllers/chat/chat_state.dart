import 'package:equatable/equatable.dart';

import '../../models/message.dart';
import '../../models/pending_message.dart';

class ChatState extends Equatable {
  const ChatState({
    this.chatId,
    this.messages = const [],
    this.pendingMessages = const [],
    this.participantIds = const [],
    this.typingUserIds = const <String>{},
    this.onlineUserIds = const <String, bool>{},
    this.isLoading = false,
    this.isSending = false,
    this.isConnected = true,
    this.errorMessage,
    this.cachedLastMessage,
  });

  final String? chatId;
  final List<Message> messages;
  final List<PendingMessage> pendingMessages;
  final List<String> participantIds;
  final Set<String> typingUserIds;
  final Map<String, bool> onlineUserIds;
  final bool isLoading;
  final bool isSending;
  final bool isConnected;
  final String? errorMessage;
  final Message? cachedLastMessage;

  bool get hasPendingMessages => pendingMessages.isNotEmpty;

  bool get isSomeoneTyping => typingUserIds.isNotEmpty;

  bool isUserOnline(String userId) => onlineUserIds[userId] ?? false;

  ChatState copyWith({
    String? chatId,
    List<Message>? messages,
    List<PendingMessage>? pendingMessages,
    List<String>? participantIds,
    Set<String>? typingUserIds,
    Map<String, bool>? onlineUserIds,
    bool? isLoading,
    bool? isSending,
    bool? isConnected,
    String? errorMessage,
    Message? cachedLastMessage,
    bool clearError = false,
  }) {
    return ChatState(
      chatId: chatId ?? this.chatId,
      messages: messages ?? this.messages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      participantIds: participantIds ?? this.participantIds,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      onlineUserIds: onlineUserIds ?? this.onlineUserIds,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isConnected: isConnected ?? this.isConnected,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      cachedLastMessage: cachedLastMessage ?? this.cachedLastMessage,
    );
  }

  @override
  List<Object?> get props => [
        chatId,
        messages,
        pendingMessages,
        participantIds,
        typingUserIds,
        onlineUserIds,
        isLoading,
        isSending,
        isConnected,
        errorMessage,
        cachedLastMessage,
      ];
}
