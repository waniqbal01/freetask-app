import 'package:equatable/equatable.dart';

abstract class ChatListEvent extends Equatable {
  const ChatListEvent();

  @override
  List<Object?> get props => [];
}

class LoadChatThreads extends ChatListEvent {
  const LoadChatThreads();
}

class RefreshChatThreads extends ChatListEvent {
  const RefreshChatThreads();
}
