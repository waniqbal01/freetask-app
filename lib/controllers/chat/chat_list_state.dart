import 'package:equatable/equatable.dart';

import '../../models/chat.dart';

class ChatListState extends Equatable {
  const ChatListState({
    this.threads = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final List<ChatThread> threads;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;

  ChatListState copyWith({
    List<ChatThread>? threads,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatListState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [threads, isLoading, isRefreshing, errorMessage];
}
