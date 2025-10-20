import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:freetask_app/controllers/auth/auth_bloc.dart';
import 'package:freetask_app/controllers/auth/auth_event.dart';
import 'package:freetask_app/controllers/auth/auth_state.dart';
import 'package:freetask_app/controllers/chat/chat_bloc.dart';
import 'package:freetask_app/controllers/chat/chat_event.dart';
import 'package:freetask_app/controllers/wallet/wallet_cubit.dart';
import 'package:freetask_app/models/auth_response.dart';
import 'package:freetask_app/models/message.dart';
import 'package:freetask_app/models/payment.dart';
import 'package:freetask_app/models/user.dart';
import 'package:freetask_app/services/auth_service.dart';
import 'package:freetask_app/services/chat_service.dart';
import 'package:freetask_app/services/chat_cache_service.dart';
import 'package:freetask_app/services/key_value_store.dart';
import 'package:freetask_app/services/socket_service.dart';
import 'package:freetask_app/services/storage_service.dart';
import 'package:freetask_app/services/wallet_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockChatService extends Mock implements ChatService {}

class _MockSocketService extends Mock implements SocketService {}

class _MockWalletService extends Mock implements WalletService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue<List<File>>(<File>[]);
  });

  group('Negative flows', () {
    late StorageService storage;
    late _MockAuthService authService;
    late _MockChatService chatService;
    late _MockSocketService socketService;
    late ChatCacheService chatCacheService;
    late _MockWalletService walletService;

    setUp(() {
      storage = StorageService(InMemoryKeyValueStore());
      authService = _MockAuthService();
      chatService = _MockChatService();
      socketService = _MockSocketService();
      walletService = _MockWalletService();
      chatCacheService = ChatCacheService(InMemoryKeyValueStore());
    });

    test('refresh token failure logs out user', () async {
      final user = User(
        id: 'user-1',
        name: 'Mira',
        email: 'mira@example.com',
        role: 'client',
      );
      final authResponse = AuthResponse(
        token: 'token',
        refreshToken: 'refresh',
        user: user,
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      );
      when(
        () => authService.login(email: any(named: 'email'), password: any(named: 'password')),
      ).thenAnswer((_) async => authResponse);
      when(() => authService.fetchMe()).thenAnswer((_) async => user);
      when(() => authService.refreshToken()).thenThrow(AuthException('Session expired.'));
      when(() => authService.logout()).thenAnswer((_) async {});

      final authBloc = AuthBloc(authService, storage);
      final emitted = <AuthState>[];
      final sub = authBloc.stream.listen(emitted.add);

      authBloc.add(const LoginSubmitted(email: 'mira@example.com', password: 'pw1234'));
      await pumpEventQueue(times: 5);
      authBloc.add(const AuthCheckRequested());
      await pumpEventQueue(times: 5);

      expect(emitted.whereType<AuthUnauthenticated>().isNotEmpty, isTrue);

      await sub.cancel();
      await authBloc.close();
    });

    test('forbidden chat send surfaces error', () async {
      final messageController = StreamController<Message>.broadcast();
      final typingController = StreamController<TypingEvent>.broadcast();
      final presenceController = StreamController<UserPresenceEvent>.broadcast();
      final statusController = StreamController<MessageStatusUpdate>.broadcast();
      final connectionController = StreamController<bool>.broadcast();

      when(() => socketService.messages).thenAnswer((_) => messageController.stream);
      when(() => socketService.typing).thenAnswer((_) => typingController.stream);
      when(() => socketService.presence).thenAnswer((_) => presenceController.stream);
      when(() => socketService.messageStatuses).thenAnswer((_) => statusController.stream);
      when(() => socketService.connection).thenAnswer((_) => connectionController.stream);
      when(() => socketService.joinChatRoom(any())).thenReturn(null);
      when(() => socketService.leaveChatRoom(any())).thenReturn(null);
      when(() => socketService.sendTyping(chatId: any(named: 'chatId'), isTyping: any(named: 'isTyping')))
          .thenReturn(null);

      when(() => chatService.fetchMessages('chat-err')).thenAnswer((_) async => const []);
      when(
        () => chatService.sendMessage(
          chatId: 'chat-err',
          text: any(named: 'text'),
          attachments: any(named: 'attachments'),
        ),
      ).thenThrow(ChatException('Forbidden action'));

      final chatBloc = ChatBloc(
        chatService,
        socketService,
        chatCacheService,
        currentUserId: 'user-2',
      );

      chatBloc.add(const ChatStarted(chatId: 'chat-err', participantIds: ['user-2', 'user-3']));
      await pumpEventQueue(times: 5);
      chatBloc.add(const SendMessageRequested(text: 'Hello there'));
      await pumpEventQueue(times: 5);

      expect(chatBloc.state.errorMessage, contains('Forbidden'));

      await chatBloc.close();
      await messageController.close();
      await typingController.close();
      await presenceController.close();
      await statusController.close();
      await connectionController.close();
    });

    test('double release prevents duplicate payout', () async {
      final payment = Payment(
        id: 'payment-1',
        jobId: 'job-1',
        amount: 300,
        status: PaymentStatus.pending,
        updatedAt: DateTime.now(),
      );
      final summary = WalletSummary(balance: 300, pending: 300, released: 0, withdrawn: 0);

      when(() => walletService.fetchSummary()).thenAnswer((_) async => summary);
      when(() => walletService.fetchPayments()).thenAnswer((_) async => [payment]);
      when(() => walletService.releasePayment(payment.id))
          .thenAnswer((_) async => payment.copyWith(status: PaymentStatus.released));

      final walletCubit = WalletCubit(walletService);
      walletCubit.load();
      await pumpEventQueue(times: 5);

      walletCubit.releasePayment(payment.id);
      await pumpEventQueue(times: 5);
      when(() => walletService.releasePayment(payment.id))
          .thenThrow(Exception('Already released'));
      walletCubit.releasePayment(payment.id);
      await pumpEventQueue(times: 5);

      expect(walletCubit.state.releaseErrors[payment.id], isNotNull);

      await walletCubit.close();
    });
  });
}
