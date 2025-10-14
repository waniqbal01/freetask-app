import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../models/message.dart';

abstract class ChatDetailEvent extends Equatable {
  const ChatDetailEvent();

  @override
  List<Object?> get props => [];
}

class LoadChatMessages extends ChatDetailEvent {
  const LoadChatMessages(this.chatId);

  final String chatId;

  @override
  List<Object?> get props => [chatId];
}

class SendChatMessage extends ChatDetailEvent {
  const SendChatMessage({
    required this.chatId,
    required this.text,
    this.image,
  });

  final String chatId;
  final String text;
  final File? image;

  @override
  List<Object?> get props => [chatId, text, image?.path];
}

class IncomingChatMessage extends ChatDetailEvent {
  const IncomingChatMessage(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}
