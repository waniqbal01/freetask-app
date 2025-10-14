import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../../services/socket_service.dart';
import '../../utils/logger.dart';
import 'chat_detail_event.dart';
import 'chat_detail_state.dart';

class ChatDetailBloc extends Bloc<ChatDetailEvent, ChatDetailState> {
  ChatDetailBloc(this._chatService, this._socketService)
      : super(const ChatDetailState()) {
    on<LoadChatMessages>(_onLoadMessages);
    on<SendChatMessage>(_onSendMessage);
    on<IncomingChatMessage>(_onIncomingMessage);
  }

  final ChatService _chatService;
  final SocketService _socketService;
  StreamSubscription<Message>? _subscription;

  Future<void> _onLoadMessages(
    LoadChatMessages event,
    Emitter<ChatDetailState> emit,
  ) async {
    _subscription ??= _socketService.messages.listen((message) {
      add(IncomingChatMessage(message));
    });

    final previousChat = state.chatId;
    if (previousChat != null && previousChat != event.chatId) {
      _socketService.leaveChatRoom(previousChat);
    }
    _socketService.joinChatRoom(event.chatId);

    emit(
      state.copyWith(
        chatId: event.chatId,
        isLoading: true,
        clearError: true,
      ),
    );
    try {
      final messages = await _chatService.fetchMessages(event.chatId);
      emit(
        state.copyWith(
          messages: messages,
          isLoading: false,
        ),
      );
    } on ChatException catch (error, stackTrace) {
      appLog('Failed to load messages', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on load messages', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load messages.',
        ),
      );
    }
  }

  Future<void> _onSendMessage(
    SendChatMessage event,
    Emitter<ChatDetailState> emit,
  ) async {
    emit(state.copyWith(isSending: true, clearError: true));
    try {
      final message = await _chatService.sendMessage(
        chatId: event.chatId,
        text: event.text,
        image: event.image,
      );
      final updatedMessages = [...state.messages, message];
      emit(
        state.copyWith(
          messages: updatedMessages,
          isSending: false,
        ),
      );
    } on ChatException catch (error, stackTrace) {
      appLog('Failed to send message', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSending: false,
          errorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      appLog('Unexpected error on send message', error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isSending: false,
          errorMessage: 'Unable to send message.',
        ),
      );
    }
  }

  void _onIncomingMessage(
    IncomingChatMessage event,
    Emitter<ChatDetailState> emit,
  ) {
    if (state.chatId != event.message.chatId) {
      return;
    }
    final existing = [...state.messages];
    final alreadyExists = existing.any((message) => message.id == event.message.id);
    if (!alreadyExists) {
      existing.add(event.message);
      existing.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      emit(state.copyWith(messages: existing));
    }
  }

  @override
  Future<void> close() {
    if (state.chatId != null) {
      _socketService.leaveChatRoom(state.chatId!);
    }
    _subscription?.cancel();
    return super.close();
  }
}
