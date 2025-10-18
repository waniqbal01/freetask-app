import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'bootstrap.dart';
import 'controllers/auth/auth_bloc.dart';
import 'controllers/auth/auth_event.dart';
import 'controllers/auth/auth_state.dart';
import 'controllers/chat/chat_list_bloc.dart';
import 'controllers/dashboard/dashboard_metrics_cubit.dart';
import 'controllers/job/job_bloc.dart';
import 'controllers/job/job_event.dart';
import 'controllers/nav/role_nav_cubit.dart';
import 'controllers/profile/profile_bloc.dart';
import 'controllers/profile/profile_state.dart';
import 'models/job_list_type.dart';
import 'screens/chat_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/jobs_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/chat_cache_service.dart';
import 'services/chat_service.dart';
import 'services/job_service.dart';
import 'services/profile_service.dart';
import 'services/role_guard.dart';
import 'services/socket_service.dart';
import 'services/storage_service.dart';
import 'utils/role_permissions.dart';

class FreetaskApp extends StatefulWidget {
  const FreetaskApp({required this.bootstrap, super.key});

  final AppBootstrap bootstrap;

  @override
  State<FreetaskApp> createState() => _FreetaskAppState();
}

class _FreetaskAppState extends State<FreetaskApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
        _storage.role ?? _storage.getUser()?.role ?? UserRoles.defaultRole;
    _authBloc = AuthBloc(widget.bootstrap.authService, _storage);
    _jobBloc = JobBloc(widget.bootstrap.jobService, _storage);
    _metricsCubit = DashboardMetricsCubit(_jobBloc, _storage);
    _roleNavCubit = RoleNavCubit(initialRole: initialRole);
    _chatListBloc = ChatListBloc(widget.bootstrap.chatService);
    _profileBloc = ProfileBloc(widget.bootstrap.profileService, _storage);

    _logoutSubscription =
        widget.bootstrap.apiClient.logoutStream.listen((_) async {
      _authBloc.add(const LogoutRequested());
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
        ),
      );
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        LoginScreen.routeName,
        (route) => false,
      );
    });

    _authSubscription = _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated) {
        _roleNavCubit.updateRole(state.user.role);
        _metricsCubit.updateRole(state.user.role);
        _jobBloc.add(const JobListRequested(JobListType.available));
        final token = _storage.token;
        if (token != null && token.isNotEmpty) {
          widget.bootstrap.socketService.connect(
            token: token,
            userId: state.user.id,
          );
        }
      } else if (state is AuthUnauthenticated) {
        widget.bootstrap.socketService.disconnect();
        _roleNavCubit.updateRole(UserRoles.defaultRole);
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

  ThemeData _buildTheme() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = base.colorScheme.copyWith(
      primary: const Color(0xFF3A7BD5),
      secondary: const Color(0xFF3A7BD5),
      tertiary: const Color(0xFF3A7BD5),
      surface: Colors.white,
      background: const Color(0xFFF9F9F9),
    );
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF9F9F9),
      fontFamily: 'Poppins',
      fontFamilyFallback: const ['Inter'],
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        elevation: 0,
        backgroundColor: colorScheme.background,
        foregroundColor: Colors.black87,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A7BD5)),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: const Color(0xFF3A7BD5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: widget.bootstrap.apiClient),
        RepositoryProvider<AuthService>.value(value: widget.bootstrap.authService),
        RepositoryProvider<StorageService>.value(value: _storage),
        RepositoryProvider<RoleGuard>.value(value: widget.bootstrap.roleGuard),
        RepositoryProvider<JobService>.value(value: widget.bootstrap.jobService),
        RepositoryProvider<ChatService>.value(value: widget.bootstrap.chatService),
        RepositoryProvider<ChatCacheService>.value(
          value: widget.bootstrap.chatCacheService,
        ),
        RepositoryProvider<ProfileService>.value(
          value: widget.bootstrap.profileService,
        ),
        RepositoryProvider<SocketService>.value(
          value: widget.bootstrap.socketService,
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
        ],
        child: _AppView(
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          theme: _buildTheme(),
        ),
      ),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView({
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
    required this.theme,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final ThemeData theme;

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case SplashScreen.routeName:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case LoginScreen.routeName:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case DashboardScreen.routeName:
        final target = settings.arguments is RoleNavTarget
            ? settings.arguments as RoleNavTarget
            : RoleNavTarget.home;
        return MaterialPageRoute<void>(
          builder: (_) => DashboardScreen(initialTarget: target),
          settings: settings,
        );
      case JobsScreen.routeName:
        return MaterialPageRoute<void>(
          builder: (_) => const DashboardScreen(initialTarget: RoleNavTarget.jobs),
          settings: settings,
        );
      case ChatScreen.routeName:
        return MaterialPageRoute<void>(
          builder: (_) => const DashboardScreen(initialTarget: RoleNavTarget.chat),
          settings: settings,
        );
      case ProfileScreen.routeName:
        return MaterialPageRoute<void>(
          builder: (_) => const DashboardScreen(initialTarget: RoleNavTarget.profile),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        theme: theme,
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        initialRoute: SplashScreen.routeName,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }
}
