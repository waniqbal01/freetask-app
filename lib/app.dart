import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bootstrap/app_bootstrap.dart';
import 'core/router/route_guard.dart';
import 'core/router/app_router.dart';
import 'config/theme.dart';
import 'controllers/auth/auth_bloc.dart';
import 'controllers/auth/auth_event.dart';
import 'controllers/auth/auth_state.dart';
import 'controllers/chat/chat_list_bloc.dart';
import 'controllers/dashboard/dashboard_metrics_cubit.dart';
import 'controllers/job/job_bloc.dart';
import 'controllers/job/job_event.dart';
import 'controllers/nav/role_nav_cubit.dart';
import 'controllers/notifications/notifications_cubit.dart';
import 'controllers/profile/profile_bloc.dart';
import 'controllers/wallet/wallet_cubit.dart';
import 'models/job_list_type.dart';
import 'models/user_roles.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/bid_service.dart';
import 'services/admin_service.dart';
import 'services/chat_cache_service.dart';
import 'services/chat_service.dart';
import 'services/job_service.dart';
import 'data/services/order_service.dart';
import 'data/services/role_service.dart';
import 'data/services/service_service.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/profile_service.dart';
import 'services/role_guard.dart';
import 'services/socket_service.dart';
import 'services/storage_service.dart';
import 'services/wallet_service.dart';
import 'repositories/auth_repository.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class FreetaskApp extends StatefulWidget {
  const FreetaskApp({required this.bootstrap, super.key});

  final AppBootstrap bootstrap;

  @override
  State<FreetaskApp> createState() => _FreetaskAppState();
}

class _FreetaskAppState extends State<FreetaskApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  late final AuthBloc _authBloc;
  late final JobBloc _jobBloc;
  late final DashboardMetricsCubit _metricsCubit;
  late final RoleNavCubit _roleNavCubit;
  late final ChatListBloc _chatListBloc;
  late final ProfileBloc _profileBloc;

  StreamSubscription<void>? _logoutSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  StorageService get _storage => widget.bootstrap.storageService;

  @override
  void initState() {
    super.initState();
    final initialRole =
        _storage.role ?? _storage.getUser()?.role ?? kDefaultUserRoleName;
    _authBloc = AuthBloc(widget.bootstrap.authRepository);
    _jobBloc = JobBloc(widget.bootstrap.jobService, _storage);
    _metricsCubit = DashboardMetricsCubit(_jobBloc, _storage);
    _roleNavCubit = RoleNavCubit(initialRole: initialRole);
    _chatListBloc = ChatListBloc(widget.bootstrap.chatService);
    _profileBloc = ProfileBloc(widget.bootstrap.profileService, _storage);

    _logoutSubscription =
        widget.bootstrap.apiClient.logoutStream.listen((_) async {
      _authBloc.add(const LogoutRequested());
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
        ),
      );
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    });

    _authSubscription = _authBloc.stream.listen((state) {
      if (state.status == AuthStatus.authenticated && state.user != null) {
        _roleNavCubit.updateRole(state.user!.role);
        _metricsCubit.updateRole(state.user!.role);
        _jobBloc.add(const JobListRequested(JobListType.available));
        final token = _storage.token;
        if (token != null && token.isNotEmpty) {
          widget.bootstrap.socketService.connect(
            token: token,
            userId: state.user!.id,
          );
        }
      } else if (state.status == AuthStatus.unauthenticated) {
        widget.bootstrap.socketService.disconnect();
        _roleNavCubit.updateRole(kDefaultUserRoleName);
      }
    });
  }

  @override
  void dispose() {
    _logoutSubscription?.cancel();
    _authSubscription?.cancel();
    _authBloc.close();
    _jobBloc.close();
    _metricsCubit.close();
    _roleNavCubit.close();
    _chatListBloc.close();
    _profileBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: widget.bootstrap.apiClient),
        RepositoryProvider<AuthService>.value(value: widget.bootstrap.authService),
        RepositoryProvider<AuthRepository>.value(
          value: widget.bootstrap.authRepository,
        ),
        RepositoryProvider<StorageService>.value(value: _storage),
        RepositoryProvider<RoleService>.value(value: widget.bootstrap.roleService),
        RepositoryProvider<RoleGuard>.value(value: widget.bootstrap.roleGuard),
        RepositoryProvider<JobService>.value(value: widget.bootstrap.jobService),
        RepositoryProvider<ChatService>.value(value: widget.bootstrap.chatService),
        RepositoryProvider<ChatCacheService>.value(
          value: widget.bootstrap.chatCacheService,
        ),
        RepositoryProvider<ProfileService>.value(
          value: widget.bootstrap.profileService,
        ),
        RepositoryProvider<PaymentService>.value(
          value: widget.bootstrap.paymentService,
        ),
        RepositoryProvider<SocketService>.value(
          value: widget.bootstrap.socketService,
        ),
        RepositoryProvider<BidService>.value(value: widget.bootstrap.bidService),
        RepositoryProvider<WalletService>.value(value: widget.bootstrap.walletService),
        RepositoryProvider<NotificationService>.value(
          value: widget.bootstrap.notificationService,
        ),
        RepositoryProvider<ServiceService>.value(
          value: widget.bootstrap.serviceService,
        ),
        RepositoryProvider<OrderService>.value(value: widget.bootstrap.orderService),
        RepositoryProvider<AdminService>.value(
          value: widget.bootstrap.adminService,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<JobBloc>.value(value: _jobBloc),
          BlocProvider<DashboardMetricsCubit>.value(value: _metricsCubit),
          BlocProvider<RoleNavCubit>.value(value: _roleNavCubit),
          BlocProvider<ChatListBloc>.value(value: _chatListBloc),
          BlocProvider<ProfileBloc>.value(value: _profileBloc),
          BlocProvider<WalletCubit>(
            create: (context) => WalletCubit(widget.bootstrap.walletService),
          ),
          BlocProvider<NotificationsCubit>(
            create: (context) =>
                NotificationsCubit(widget.bootstrap.notificationService, _storage),
          ),
        ],
        child: _AppView(
          navigatorKey: _navigatorKey,
          theme: FreetaskTheme.build(),
        ),
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView({
    required this.navigatorKey,
    required this.theme,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final ThemeData theme;

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  RouteGuard? _routeGuard;
  AppRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeGuard == null) {
      final roleService = RepositoryProvider.of<RoleService>(context);
      _routeGuard = RouteGuard(roleService);
      _router = AppRouter(_routeGuard!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = _router!;
    final routeGuard = _routeGuard!;
    return BlocListener<ProfileBloc, ProfileState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.successMessage != current.successMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        } else if (state.successMessage != null) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(state.successMessage!)),
          );
        }
      },
      child: MaterialApp(
        title: 'Freetask',
        theme: widget.theme,
        debugShowCheckedModeBanner: false,
        navigatorKey: widget.navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        initialRoute: AppRoutes.onboarding,
        onGenerateRoute: router.onGenerateRoute,
        navigatorObservers: [routeGuard],
      ),
    );
  }
}
