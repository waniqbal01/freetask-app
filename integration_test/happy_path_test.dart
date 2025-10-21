import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:freetask_app/controllers/auth/auth_bloc.dart';
import 'package:freetask_app/controllers/auth/auth_event.dart';
import 'package:freetask_app/controllers/auth/auth_state.dart';
import 'package:freetask_app/controllers/job/job_bloc.dart';
import 'package:freetask_app/controllers/job/job_event.dart';
import 'package:freetask_app/controllers/job/job_state.dart';
import 'package:freetask_app/controllers/wallet/wallet_cubit.dart';
import 'package:freetask_app/controllers/wallet/wallet_state.dart';
import 'package:freetask_app/controllers/chat/chat_bloc.dart';
import 'package:freetask_app/controllers/chat/chat_event.dart';
import 'package:freetask_app/controllers/chat/chat_state.dart';
import 'package:freetask_app/models/auth_response.dart';
import 'package:freetask_app/models/job.dart';
import 'package:freetask_app/models/job_list_type.dart';
import 'package:freetask_app/models/message.dart';
import 'package:freetask_app/models/review.dart';
import 'package:freetask_app/models/user.dart';
import 'package:freetask_app/models/payment.dart';
import 'package:freetask_app/services/auth_service.dart';
import 'package:freetask_app/services/chat_service.dart';
import 'package:freetask_app/services/chat_cache_service.dart';
import 'package:freetask_app/services/job_service.dart';
import 'package:freetask_app/services/socket_service.dart';
import 'package:freetask_app/services/storage_service.dart';
import 'package:freetask_app/services/wallet_service.dart';
import 'package:freetask_app/services/key_value_store.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockJobService extends Mock implements JobService {}

class _MockChatService extends Mock implements ChatService {}

class _MockSocketService extends Mock implements SocketService {}

class _MockWalletService extends Mock implements WalletService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(<File>[]);
  });

  group('Happy path integration', () {
    late StorageService storage;
    late _MockAuthService authService;
    late _MockJobService jobService;
    late _MockChatService chatService;
    late _MockSocketService socketService;
    late _MockWalletService walletService;
    late ChatCacheService chatCacheService;

    setUp(() {
      storage = StorageService(InMemoryKeyValueStore());
      authService = _MockAuthService();
      jobService = _MockJobService();
      chatService = _MockChatService();
      socketService = _MockSocketService();
      walletService = _MockWalletService();
      chatCacheService = ChatCacheService(InMemoryKeyValueStore());
    });

    test('signup → job lifecycle → chat → payment release', () async {
      final user = User(
        id: 'user-1',
        name: 'Aisha Client',
        email: 'aisha@example.com',
        role: 'client',
        averageRating: 4.8,
        reviewCount: 12,
      );
      final authResponse = AuthResponse(
        token: 'token-abc',
        refreshToken: 'refresh-xyz',
        user: user,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      when(
        () => authService.signup(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          role: any(named: 'role'),
        ),
      ).thenAnswer((_) async => authResponse);
      when(() => authService.fetchMe()).thenAnswer((_) async => user);
      when(() => authService.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => authResponse);

      final authBloc = AuthBloc(authService, storage);
      final authStates = <AuthState>[];
      final authSub = authBloc.stream.listen(authStates.add);

      authBloc.add(const SignupSubmitted(
        name: 'Aisha Client',
        email: 'aisha@example.com',
        password: 'password',
        role: 'client',
      ));
      await pumpEventQueue(times: 5);

      expect(authStates.whereType<AuthAuthenticated>().length, 1);
      expect(storage.getUser(), isNotNull);

      final createdJob = Job(
        id: 'job-1',
        title: 'Design Landing Page',
        description: 'Need a clean landing page mockup',
        price: 500,
        category: 'Design',
        location: 'Remote',
        status: JobStatus.pending,
        clientId: user.id,
        createdAt: DateTime.now(),
      );
      final acceptedJob = createdJob.copyWith(status: JobStatus.inProgress, freelancerId: 'freelancer-1');
      final completedJob = acceptedJob.copyWith(status: JobStatus.completed);

      when(
        () => jobService.fetchJobs(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          category: any(named: 'category'),
          search: any(named: 'search'),
          mine: any(named: 'mine'),
          includeHistory: any(named: 'includeHistory'),
          minBudget: any(named: 'minBudget'),
          maxBudget: any(named: 'maxBudget'),
          location: any(named: 'location'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => JobPaginationResult(jobs: [createdJob], page: 1, pageSize: 20, total: 1));
      when(
        () => jobService.createJob(
          title: any(named: 'title'),
          description: any(named: 'description'),
          price: any(named: 'price'),
          category: any(named: 'category'),
          location: any(named: 'location'),
          imagePaths: any(named: 'imagePaths'),
        ),
      ).thenAnswer((_) async => createdJob);
      when(() => jobService.acceptJob(createdJob.id)).thenAnswer((_) async => acceptedJob);
      when(() => jobService.completeJob(createdJob.id)).thenAnswer((_) async => completedJob);
      when(
        () => jobService.submitReview(
          jobId: createdJob.id,
          rating: any(named: 'rating'),
          comment: any(named: 'comment'),
        ),
      ).thenAnswer((_) async => Review(
            id: 'review-1',
            jobId: createdJob.id,
            reviewerId: user.id,
            rating: 5,
            comment: 'Excellent work!',
            createdAt: DateTime.now(),
          ));

      final jobBloc = JobBloc(jobService, storage);
      final jobStates = <JobState>[];
      final jobSub = jobBloc.stream.listen(jobStates.add);
      storage.saveUser(user);

      jobBloc.add(const JobListRequested(JobListType.available));
      await pumpEventQueue(times: 5);
      jobBloc.add(CreateJobRequested(
        title: createdJob.title,
        description: createdJob.description,
        price: createdJob.price,
        category: createdJob.category,
        location: createdJob.location,
      ));
      await pumpEventQueue(times: 5);
      jobBloc.add(AcceptJobRequested(createdJob.id));
      await pumpEventQueue(times: 5);
      jobBloc.add(CompleteJobRequested(createdJob.id));
      await pumpEventQueue(times: 5);

      final reviewPrompt = jobBloc.state.reviewPromptJob;
      expect(reviewPrompt, isNotNull);
      expect(reviewPrompt!.status, JobStatus.completed);

      jobBloc.add(SubmitJobReviewRequested(jobId: createdJob.id, rating: 5, comment: 'Great!'));
      await pumpEventQueue(times: 5);
      expect(jobBloc.state.submittedReview, isNotNull);

      final outgoingMessage = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: user.id,
        text: 'Hello!',
        attachments: const [],
        createdAt: DateTime.now(),
        status: MessageDeliveryStatus.sent,
      );

      when(() => chatService.fetchMessages('chat-1')).thenAnswer((_) async => const []);
      when(
        () => chatService.sendMessage(
          chatId: 'chat-1',
          text: any(named: 'text'),
          attachments: any(named: 'attachments'),
        ),
      ).thenAnswer((_) async => outgoingMessage);
      when(
        () => chatService.markMessagesRead(chatId: any(named: 'chatId'), messageIds: any(named: 'messageIds')),
      ).thenAnswer((_) async {});

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
      when(() => socketService.joinChatRoom(any())).thenAnswer((_) async {});
      when(() => socketService.leaveChatRoom(any())).thenAnswer((_) async {});
      when(() => socketService.sendTyping(chatId: any(named: 'chatId'), isTyping: any(named: 'isTyping')))
          .thenAnswer((_) async {});
      when(() => socketService.sendReadReceipt(chatId: any(named: 'chatId'), messageIds: any(named: 'messageIds')))
          .thenAnswer((_) async {});

      final chatBloc = ChatBloc(
        chatService,
        socketService,
        chatCacheService,
        currentUserId: user.id,
      );
      final chatStates = <ChatState>[];
      final chatSub = chatBloc.stream.listen(chatStates.add);

      chatBloc.add(ChatStarted(chatId: 'chat-1', participantIds: ['freelancer-1', user.id]));
      await pumpEventQueue(times: 5);
      chatBloc.add(const SendMessageRequested(text: 'Hello!'));
      await pumpEventQueue(times: 5);

      statusController.add(MessageStatusUpdate(
        chatId: 'chat-1',
        messageId: outgoingMessage.id,
        status: MessageDeliveryStatus.delivered,
        deliveredAt: DateTime.now(),
      ));
      await pumpEventQueue(times: 5);

      expect(chatBloc.state.messages.last.status, MessageDeliveryStatus.delivered);

      final summary = WalletSummary(balance: 500, pending: 500, released: 0, withdrawn: 0);
      final pendingPayment = Payment(
        id: 'payment-1',
        jobId: createdJob.id,
        amount: 500,
        status: PaymentStatus.pending,
        updatedAt: DateTime.now(),
      );
      final releasedPayment = pendingPayment.copyWith(status: PaymentStatus.released);

      when(() => walletService.fetchSummary()).thenAnswer((_) async => summary);
      when(() => walletService.fetchPayments()).thenAnswer((_) async => [pendingPayment]);
      when(() => walletService.releasePayment(pendingPayment.id))
          .thenAnswer((_) async => releasedPayment);

      final walletCubit = WalletCubit(walletService);
      walletCubit.load();
      await pumpEventQueue(times: 5);
      expect(walletCubit.state.status, WalletViewStatus.loaded);

      walletCubit.releasePayment(pendingPayment.id);
      await pumpEventQueue(times: 5);
      expect(walletCubit.state.payments.first.status, PaymentStatus.released);

      await authSub.cancel();
      await jobSub.cancel();
      await chatSub.cancel();
      await messageController.close();
      await typingController.close();
      await presenceController.close();
      await statusController.close();
      await connectionController.close();
      await authBloc.close();
      await jobBloc.close();
      await chatBloc.close();
      await walletCubit.close();
    });
  });
}
