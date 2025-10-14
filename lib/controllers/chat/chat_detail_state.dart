import 'package:equatable/equatable.dart';

import '../../models/message.dart';

class ChatDetailState extends Equatable {
  const ChatDetailState({
    this.chatId,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
  });

  final String? chatId;
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;

  ChatDetailState copyWith({
    String? chatId,
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatDetailState(
      chatId: chatId ?? this.chatId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [chatId, messages, isLoading, isSending, errorMessage];
}
