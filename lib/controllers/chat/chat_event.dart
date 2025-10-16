import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../models/message.dart';
import '../../models/pending_message.dart';
import '../../services/socket_service.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatStarted extends ChatEvent {
  const ChatStarted({required this.chatId, required this.participantIds});

  final String chatId;
  final List<String> participantIds;

  @override
  List<Object?> get props => [chatId, participantIds];
}

class SendMessageRequested extends ChatEvent {
  const SendMessageRequested({
    required this.text,
    this.attachments = const [],
  });

  final String text;
  final List<File> attachments;

  @override
  List<Object?> get props => [text, attachments.map((file) => file.path).toList()];
}

class MessageReceived extends ChatEvent {
  const MessageReceived(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}

class MessageStatusReceived extends ChatEvent {
  const MessageStatusReceived(this.update);

  final MessageStatusUpdate update;

  @override
  List<Object?> get props => [update];
}

class TypingStatusReceived extends ChatEvent {
  const TypingStatusReceived(this.event);

  final TypingEvent event;

  @override
  List<Object?> get props => [event];
}

class PresenceStatusReceived extends ChatEvent {
  const PresenceStatusReceived(this.event);

  final UserPresenceEvent event;

  @override
  List<Object?> get props => [event];
}

class TypingStatusRequested extends ChatEvent {
  const TypingStatusRequested(this.isTyping);

  final bool isTyping;

  @override
  List<Object?> get props => [isTyping];
}

class RetryPendingMessages extends ChatEvent {
  const RetryPendingMessages();
}

class OutgoingMessageUpdated extends ChatEvent {
  const OutgoingMessageUpdated({
    required this.localId,
    required this.status,
    this.remoteMessage,
    this.errorMessage,
  });

  final String localId;
  final MessageDeliveryStatus status;
  final Message? remoteMessage;
  final String? errorMessage;

  @override
  List<Object?> get props => [localId, status, remoteMessage, errorMessage];
}

class ChatConnectionChanged extends ChatEvent {
  const ChatConnectionChanged(this.isConnected);

  final bool isConnected;

  @override
  List<Object?> get props => [isConnected];
}

class ReadReceiptRequested extends ChatEvent {
  const ReadReceiptRequested(this.messageIds);

  final List<String> messageIds;

  @override
  List<Object?> get props => [messageIds];
}

class PendingQueueLoaded extends ChatEvent {
  const PendingQueueLoaded(this.pendingMessages);

  final List<PendingMessage> pendingMessages;

  @override
  List<Object?> get props => [pendingMessages];
}
