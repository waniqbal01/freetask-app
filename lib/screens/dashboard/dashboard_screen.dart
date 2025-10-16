import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../config/routes.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/chat/chat_list_bloc.dart';
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/nav/role_nav_cubit.dart';
import '../../models/job.dart';
import '../../models/message.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service.dart';
import '../../services/storage_service.dart';
import '../../utils/role_permissions.dart';
import '../chat/chat_list_screen.dart';
import '../jobs/create_job_screen.dart';
import '../jobs/job_list_screen.dart';
import '../profile/profile_screen.dart';
import '../unauthorized/unauthorized_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) => current is AuthUnauthenticated,
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
        }
      },
      buildWhen: (previous, current) => previous.runtimeType != current.runtimeType || previous.role != current.role,
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return DashboardShell(
            key: ValueKey(state.user.role),
            authState: state,
          );
        }
        if (state is AuthLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const UnauthorizedScreen();
      },
    );
  }
}

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.authState});

  final AuthAuthenticated authState;

  String get role => authState.user.role;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final _getIt = GetIt.instance;
  late final SocketService _socketService;
  late final NotificationService _notificationService;
  late final StorageService _storageService;
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _socketService = _getIt<SocketService>();
    _notificationService = _getIt<NotificationService>();
    _storageService = _getIt<StorageService>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configureForAuth(widget.authState);
    });
  }

  @override
  void didUpdateWidget(covariant DashboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authState.user.id != widget.authState.user.id ||
        oldWidget.authState.user.role != widget.authState.user.role) {
      _configureForAuth(widget.authState);
    }
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _messageSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _configureForAuth(AuthAuthenticated state) {
    if (!mounted) return;
    context.read<RoleNavCubit>().updateRole(state.user.role);
    final token = _storageService.token;
    if (token != null && token.isNotEmpty) {
      _socketService.connect(token: token, userId: state.user.id);
      _messageSubscription?.cancel();
      _messageSubscription = _socketService.messages.listen((message) {
        if (!mounted || message.senderId == state.user.id) return;
        context.read<ChatListBloc>().add(const RefreshChatThreads());
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New message received.')),
          );
        }
      });
    }

    _notificationService.initialize();
    _notificationSubscription ??=
        _notificationService.messages.listen((remoteMessage) {
      final notification = remoteMessage.notification;
      if (!mounted || notification == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification.title ?? 'Notification'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoleNavCubit, RoleNavState>(
      builder: (context, navState) {
        final pages = navState.tabs
            .map((tab) => _buildPage(context, tab.target))
            .toList();

        final currentTab = navState.tabs[navState.index];

        return Scaffold(
          appBar: AppBar(
            title: Text(currentTab.label),
          ),
          body: IndexedStack(
            index: navState.index,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: navState.index,
            onDestinationSelected: (value) {
              context.read<RoleNavCubit>().setIndex(value);
              final target = navState.tabs[value].target;
              if (target == RoleNavTarget.myJobs) {
                context.read<JobBloc>().add(const LoadJobList(JobListType.mine));
              } else if (target == RoleNavTarget.availableJobs) {
                context
                    .read<JobBloc>()
                    .add(const LoadJobList(JobListType.available));
              }
            },
            destinations: navState.tabs
                .map(
                  (tab) => NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, RoleNavTarget target) {
    switch (target) {
      case RoleNavTarget.availableJobs:
        return JobListScreen(
          key: const ValueKey('available_jobs_tab'),
          initialTab: JobListType.available,
        );
      case RoleNavTarget.myJobs:
        return JobListScreen(
          key: const ValueKey('my_jobs_tab'),
          initialTab: JobListType.mine,
          showCreateButton:
              context.read<RoleNavCubit>().state.role == UserRoles.client,
          onCreatePressed: () {
            final roleNavCubit = context.read<RoleNavCubit>();
            final createIndex = roleNavCubit.state.tabs
                .indexWhere((tab) => tab.target == RoleNavTarget.createJob);
            if (createIndex != -1) {
              roleNavCubit.setIndex(createIndex);
            }
          },
        );
      case RoleNavTarget.createJob:
        return const CreateJobScreen();
      case RoleNavTarget.chat:
        return const ChatListScreen(key: ValueKey('chat_list_tab'));
      case RoleNavTarget.profile:
        return const ProfileScreen();
      case RoleNavTarget.overview:
        return const _PlaceholderScreen(
          title: 'Overview',
          subtitle: 'Admin overview dashboard coming soon.',
        );
      case RoleNavTarget.users:
        return const _PlaceholderScreen(
          title: 'Users',
          subtitle: 'User management tools are under development.',
        );
      case RoleNavTarget.jobs:
        return JobListScreen(
          key: const ValueKey('admin_jobs_tab'),
          initialTab: JobListType.available,
        );
    }
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
