import 'package:bloc/bloc.dart';

import '../../services/chat_service.dart';
import '../../utils/logger.dart';
import 'chat_list_event.dart';
import 'chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  ChatListBloc(this._chatService) : super(const ChatListState()) {
    on<LoadChatThreads>(_onLoadThreads);
    on<RefreshChatThreads>(_onRefreshThreads);
  }

  final ChatService _chatService;

  Future<void> _onLoadThreads(
    LoadChatThreads event,
    Emitter<ChatListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final threads = await _chatService.fetchThreads();
      emit(state.copyWith(isLoading: false, threads: threads));
    } on ChatException catch (error, stackTrace) {
      appLog('Failed to load chat threads', error: error, stackTrace: stackTrace);
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    } catch (error, stackTrace) {
      appLog('Unexpected error on load chat threads',
          error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load chats.',
        ),
      );
    }
  }

  Future<void> _onRefreshThreads(
    RefreshChatThreads event,
    Emitter<ChatListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    try {
      final threads = await _chatService.fetchThreads();
      emit(
        state.copyWith(
          isRefreshing: false,
          threads: threads,
        ),
      );
    } on ChatException catch (error, stackTrace) {
      appLog('Failed to refresh chat threads', error: error, stackTrace: stackTrace);
      emit(state.copyWith(isRefreshing: false, errorMessage: error.message));
    } catch (error, stackTrace) {
      appLog('Unexpected error on refresh chat threads',
          error: error, stackTrace: stackTrace);
      emit(
        state.copyWith(
          isRefreshing: false,
          errorMessage: 'Unable to refresh chats.',
        ),
      );
    }
  }
}
