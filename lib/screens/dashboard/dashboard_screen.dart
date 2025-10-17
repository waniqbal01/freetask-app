import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../config/routes.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/chat/chat_list_bloc.dart';
import '../../controllers/chat/chat_list_event.dart';
import '../../controllers/connectivity/connectivity_cubit.dart';
import '../../controllers/dashboard/dashboard_metrics_cubit.dart';
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/job/job_state.dart';
import '../../models/job_list_type.dart';
import '../../controllers/nav/role_nav_cubit.dart';
import '../../models/job.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service.dart';
import '../../services/storage_service.dart';
import '../../services/telemetry_service.dart';
import '../../utils/role_permissions.dart';
import '../chat/chat_list_screen.dart';
import '../jobs/create_job_screen.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_list_screen.dart';
import '../profile/profile_screen.dart';
import '../unauthorized/unauthorized_screen.dart';

/// Entry point for the dashboard. It reacts to the authentication state and
/// presents either the role-aware shell, a loading spinner or an unauthorized
/// screen.
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
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType || previous.role != current.role,
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

/// Wraps the bottom navigation, socket connections and notifications for the
/// dashboard experience. The widget reacts to role changes so that the UI can
/// adjust seamlessly when a user switches accounts.
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
  late final ChatService _chatService;
  late final TelemetryService _telemetryService;

  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _socketService = _getIt<SocketService>();
    _notificationService = _getIt<NotificationService>();
    _storageService = _getIt<StorageService>();
    _chatService = _getIt<ChatService>();
    _telemetryService = _getIt<TelemetryService>();

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
    final role = state.user.role;
    context.read<RoleNavCubit>().updateRole(role);
    context.read<DashboardMetricsCubit>().updateRole(role);
    _primeJobFeed(role);

    final token = _storageService.token;
    if (token != null && token.isNotEmpty) {
      _socketService.connect(token: token, userId: state.user.id);
      _messageSubscription?.cancel();
      _messageSubscription = _socketService.messages.listen((message) {
        if (!mounted || message.senderId == state.user.id) return;
        context.read<ChatListBloc>().add(const LoadChatThreads());
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New message received.')),
          );
        }
      });
    }

    _notificationService.initialize();
    _notificationSubscription ??= _notificationService.messages.listen(
      (remoteMessage) async {
        final notification = remoteMessage.notification;
        if (!mounted || notification == null) return;
        final data = remoteMessage.data;
        final snackBar = SnackBar(content: Text(notification.title ?? 'Notification'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        await _telemetryService.record('push_received', properties: {
          'title': notification.title,
          'userId': state.user.id,
        });
        if (data.containsKey('chatId')) {
          final chatId = data['chatId'].toString();
          if (chatId.isNotEmpty) {
            if (!mounted) return;
            Navigator.of(context).pushNamed(AppRoutes.chat, arguments: chatId);
          }
        } else if (data.containsKey('jobId')) {
          final jobId = data['jobId'].toString();
          if (jobId.isNotEmpty) {
            if (!mounted) return;
            Navigator.of(context).pushNamed(AppRoutes.jobDetail, arguments: jobId);
          }
        }
      },
    );
  }

  void _primeJobFeed(String role) {
    final bloc = context.read<JobBloc>();
    final homeList = _homeListType(role);
    bloc
      ..add(JobTabChanged(homeList))
      ..add(JobListRequested(homeList, refresh: true));
  }

  JobListType _homeListType(String role) {
    if (role == UserRoles.client) {
      return JobListType.mine;
    }
    if (role == UserRoles.freelancer) {
      return JobListType.available;
    }
    return JobListType.all;
  }

  JobListType _jobsTabType(String role) {
    if (role == UserRoles.client) {
      return JobListType.mine;
    }
    if (role == UserRoles.freelancer) {
      return JobListType.available;
    }
    return JobListType.all;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityCubit, ConnectivityState>(
      listenWhen: (previous, current) =>
          previous.isOffline != current.isOffline && !current.isOffline,
      listener: (context, state) async {
        await _chatService.flushPendingQueues();
        await _telemetryService.record('connectivity_restored', properties: {
          'userId': widget.authState.user.id,
        });
      },
      child: BlocBuilder<RoleNavCubit, RoleNavState>(
        builder: (context, navState) {
          final pages = navState.tabs
              .map((tab) => _buildPage(context, tab.target))
              .toList(growable: false);
          final currentTab = navState.tabs[navState.index];

          return Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                IndexedStack(
                  index: navState.index,
                  children: pages,
                ),
                const _OfflineBanner(),
              ],
            ),
            floatingActionButton: _buildFab(currentTab.target),
            bottomNavigationBar: NavigationBar(
              selectedIndex: navState.index,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: navState.tabs
                  .map(
                    (tab) => NavigationDestination(
                      icon: Icon(tab.icon),
                      selectedIcon: Icon(tab.selectedIcon),
                      label: tab.label,
                    ),
                  )
                  .toList(growable: false),
              onDestinationSelected: (index) {
                context.read<RoleNavCubit>().setIndex(index);
                final target = navState.tabs[index].target;
                final bloc = context.read<JobBloc>();
                switch (target) {
                  case RoleNavTarget.home:
                    final list = _homeListType(widget.role);
                    bloc
                      ..add(JobTabChanged(list))
                      ..add(JobListRequested(list, refresh: true));
                    break;
                  case RoleNavTarget.jobs:
                    final list = _jobsTabType(widget.role);
                    bloc
                      ..add(JobTabChanged(list))
                      ..add(JobListRequested(list, refresh: true));
                    break;
                  case RoleNavTarget.chat:
                  case RoleNavTarget.profile:
                    break;
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget? _buildFab(RoleNavTarget target) {
    final role = widget.role;
    if (role == UserRoles.client && target != RoleNavTarget.chat) {
      return FloatingActionButton.extended(
        heroTag: 'fab_create_job',
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Create Job'),
        onPressed: () {
          _telemetryService.record('fab_create_job_tapped', properties: {
            'userId': widget.authState.user.id,
          });
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CreateJobScreen(),
              fullscreenDialog: true,
            ),
          );
        },
      );
    }

    if (role == UserRoles.freelancer && target == RoleNavTarget.home) {
      return FloatingActionButton(
        heroTag: 'fab_filter_jobs',
        onPressed: () => _showFilterSheet(),
        tooltip: 'Filter jobs',
        child: const Icon(Icons.tune),
      );
    }

    return null;
  }

  void _showFilterSheet() {
    final jobBloc = context.read<JobBloc>();
    final feed = jobBloc.state.feedFor(_homeListType(widget.role));
    final controller = TextEditingController(text: feed.locationFilter ?? '');
    final minBudget = (feed.minBudget ?? 0).clamp(0, 10000).toDouble();
    final maxBudget = (feed.maxBudget ?? 10000).clamp(0, 20000).toDouble();
    RangeValues rangeValues = minBudget <= maxBudget
        ? RangeValues(minBudget, maxBudget)
        : RangeValues(maxBudget, minBudget);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter jobs',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text('Budget range', style: theme.textTheme.labelMedium),
              RangeSlider(
                values: rangeValues,
                min: 0,
                max: 20000,
                divisions: 40,
                labels: RangeLabels(
                  'RM ${rangeValues.start.round()}',
                  'RM ${rangeValues.end.round()}',
                ),
                onChanged: (values) {
                  rangeValues = values;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        jobBloc.add(
                          JobFilterChanged(
                            type: _homeListType(widget.role),
                            clearBudget: true,
                            clearLocation: true,
                          ),
                        );
                        _telemetryService.record('filter_cleared', properties: {
                          'userId': widget.authState.user.id,
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        jobBloc.add(
                          JobFilterChanged(
                            type: _homeListType(widget.role),
                            minBudget: rangeValues.start,
                            maxBudget: rangeValues.end,
                            location: controller.text.trim().isEmpty
                                ? null
                                : controller.text.trim(),
                          ),
                        );
                        _telemetryService.record('filter_applied', properties: {
                          'userId': widget.authState.user.id,
                          'minBudget': rangeValues.start,
                          'maxBudget': rangeValues.end,
                          'location': controller.text.trim(),
                        });
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage(BuildContext context, RoleNavTarget target) {
    final role = widget.role;
    switch (target) {
      case RoleNavTarget.home:
        return DashboardHomeTab(
          authState: widget.authState,
          role: role,
          telemetryService: _telemetryService,
          listType: _homeListType(role),
        );
      case RoleNavTarget.chat:
        return const ChatListScreen(key: ValueKey('chat_tab'));
      case RoleNavTarget.jobs:
        return JobListScreen(
          key: ValueKey('jobs_tab_$role'),
          initialTab: _jobsTabType(role),
          showCreateButton: role == UserRoles.client,
          onCreatePressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CreateJobScreen(),
                fullscreenDialog: true,
              ),
            );
          },
        );
      case RoleNavTarget.profile:
        return const ProfileScreen();
    }
  }
}

/// Displays a dismissible banner whenever the app is offline.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
        builder: (context, state) {
          return AnimatedSlide(
            offset: state.isOffline ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: Material(
              color: theme.colorScheme.error,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: theme.colorScheme.onError),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Offline. We\'ll sync as soon as you\'re back online.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onError,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Role-aware home tab that shows the greeting header, metrics cards and the
/// contextual job feed with search, filters and infinite scrolling.
class DashboardHomeTab extends StatefulWidget {
  const DashboardHomeTab({
    required this.authState,
    required this.role,
    required this.telemetryService,
    required this.listType,
    super.key,
  });

  final AuthAuthenticated authState;
  final String role;
  final TelemetryService telemetryService;
  final JobListType listType;

  @override
  State<DashboardHomeTab> createState() => _DashboardHomeTabState();
}

class _DashboardHomeTabState extends State<DashboardHomeTab> {
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels + 320 >= position.maxScrollExtent) {
      context.read<JobBloc>().add(JobLoadMoreRequested(widget.listType));
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<JobBloc>().add(
            JobSearchChanged(type: widget.listType, query: query.trim()),
          );
      widget.telemetryService.record('job_search_updated', properties: {
        'query': query.trim(),
        'role': widget.role,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.authState.user;
    return BlocBuilder<JobBloc, JobState>(
      buildWhen: (previous, current) =>
          previous.feedFor(widget.listType) != current.feedFor(widget.listType),
      builder: (context, jobState) {
        final feed = jobState.feedFor(widget.listType);
        _searchController.value = _searchController.value.copyWith(
          text: feed.searchQuery,
          selection: TextSelection.collapsed(offset: feed.searchQuery.length),
        );
        _locationController.value = _locationController.value.copyWith(
          text: feed.locationFilter ?? '',
          selection: TextSelection.collapsed(offset: (feed.locationFilter ?? '').length),
        );

        return RefreshIndicator(
          onRefresh: () async {
            context.read<JobBloc>().add(JobListRequested(widget.listType, refresh: true));
            widget.telemetryService.record('job_feed_refreshed', properties: {
              'role': widget.role,
            });
          },
          child: NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (notification) {
              notification.disallowIndicator();
              return false;
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: _DashboardHeader(
                    userName: user.name,
                    avatarUrl: user.avatarUrl,
                    onAvatarTap: () {
                      widget.telemetryService.record('profile_avatar_tapped', properties: {
                        'userId': user.id,
                      });
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    onNotificationsTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notification center coming soon.')),
                      );
                      widget.telemetryService.record('notification_icon_tapped', properties: {
                        'userId': user.id,
                      });
                    },
                  ),
                ),
                BlocBuilder<DashboardMetricsCubit, DashboardMetricsState>(
                  builder: (context, metricsState) {
                    if (metricsState.loading) {
                      return const _MetricsShimmer();
                    }
                    return SliverToBoxAdapter(
                      child: _MetricsGrid(metrics: metricsState.metrics),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            labelText: 'Search jobs',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: feed.searchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                    icon: const Icon(Icons.clear),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _FilterChip(
                              label: 'Pending',
                              selected: feed.statusFilter == JobStatus.pending,
                              onSelected: (value) {
                                context.read<JobBloc>().add(
                                      JobFilterChanged(
                                        type: widget.listType,
                                        status: value ? JobStatus.pending : null,
                                      ),
                                    );
                              },
                            ),
                            _FilterChip(
                              label: 'In Progress',
                              selected: feed.statusFilter == JobStatus.inProgress,
                              onSelected: (value) {
                                context.read<JobBloc>().add(
                                      JobFilterChanged(
                                        type: widget.listType,
                                        status: value ? JobStatus.inProgress : null,
                                      ),
                                    );
                              },
                            ),
                            _FilterChip(
                              label: 'Completed',
                              selected: feed.statusFilter == JobStatus.completed,
                              onSelected: (value) {
                                context.read<JobBloc>().add(
                                      JobFilterChanged(
                                        type: widget.listType,
                                        status: value ? JobStatus.completed : null,
                                      ),
                                    );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (feed.isLoadingInitial)
                  const _FeedShimmer()
                else if (feed.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text(
                            'No jobs to show yet',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters or come back later for fresh opportunities.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final job = feed.jobs[index];
                        return _JobCard(
                          job: job,
                          role: widget.role,
                          currentUserId: widget.authState.user.id,
                          telemetryService: widget.telemetryService,
                        );
                      },
                      childCount: feed.jobs.length,
                    ),
                  ),
                if (feed.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.userName,
    required this.avatarUrl,
    required this.onAvatarTap,
    required this.onNotificationsTap,
  });

  final String userName;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = _greeting();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName.isEmpty ? 'Welcome back!' : userName,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationsTap,
            icon: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Profile avatar',
            image: true,
            button: true,
            child: InkWell(
              onTap: onAvatarTap,
              borderRadius: BorderRadius.circular(24),
              child: Hero(
                tag: 'profile_avatar_hero',
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage:
                      avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? Text(
                          userName.isEmpty ? '?' : userName[0].toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Grid of metrics tailored to the active role.
class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<DashboardMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          final crossAxisCount = isWide
              ? 4
              : (metrics.isEmpty ? 2 : metrics.length.clamp(2, 3) as int);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: metrics.length,
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return _MetricCard(metric: metric, colorScheme: theme.colorScheme);
            },
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.colorScheme});

  final DashboardMetricData metric;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${metric.label} ${metric.value}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(opacity: value, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(metric.icon, color: colorScheme.primary),
              const Spacer(),
              Text(
                metric.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsShimmer extends StatelessWidget {
  const _MetricsShimmer();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: List.generate(
            3,
            (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 2 ? 0 : 12),
                child: _ShimmerBox(height: 120, borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedShimmer extends StatelessWidget {
  const _FeedShimmer();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: List.generate(
            4,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ShimmerBox(height: 140, borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({required this.height, required this.borderRadius});

  final double height;
  final BorderRadius borderRadius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1, 0),
              end: Alignment(1, 0),
              colors: [
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.role,
    required this.currentUserId,
    required this.telemetryService,
  });

  final Job job;
  final String role;
  final String currentUserId;
  final TelemetryService telemetryService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = NumberFormat.currency(symbol: 'RM', decimalDigits: 0).format(job.price);
    final subtitle = switch (role) {
      UserRoles.client => job.freelancerName?.isNotEmpty ?? false
          ? 'Assigned to ${job.freelancerName}'
          : 'Awaiting freelancer',
      UserRoles.freelancer => 'Posted by ${job.clientName ?? 'client'}',
      _ => job.clientName != null ? 'Client ${job.clientName}' : 'Admin view',
    };
    final timeAgo = _formatRelative(job.updatedAt ?? job.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openJobDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _StatusBadge(status: job.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(price, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(timeAgo, style: theme.textTheme.bodySmall),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        job.location.isEmpty ? 'Remote' : job.location,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: _actions(context)
                      .map(
                        (action) => SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            icon: Icon(action.icon),
                            label: Text(action.label),
                            onPressed: action.onPressed,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_JobAction> _actions(BuildContext context) {
    final actions = <_JobAction>[
      _JobAction(
        label: 'View',
        icon: Icons.visibility_outlined,
        onPressed: () => _openJobDetail(context),
      ),
    ];

    if (role == UserRoles.client) {
      actions.add(
        _JobAction(
          label: 'Chat',
          icon: Icons.chat_bubble_outline,
          onPressed: () {
            telemetryService.record('job_chat_tapped', properties: {
              'jobId': job.id,
            });
            Navigator.of(context).pushNamed(AppRoutes.chat, arguments: job.id);
          },
        ),
      );
      if (job.status == JobStatus.inProgress) {
        actions.add(
          _JobAction(
            label: 'Complete',
            icon: Icons.check_circle_outline,
            onPressed: () {
              context.read<JobBloc>().add(CompleteJobRequested(job.id));
              telemetryService.record('job_completed', properties: {'jobId': job.id});
            },
          ),
        );
      }
      if (job.status == JobStatus.completed) {
        actions.add(
          _JobAction(
            label: 'Pay',
            icon: Icons.payments_outlined,
            onPressed: () {
              context.read<JobBloc>().add(PayJobRequested(job.id));
              telemetryService.record('job_paid', properties: {'jobId': job.id});
            },
          ),
        );
      }
    } else if (role == UserRoles.freelancer) {
      if (job.status == JobStatus.pending && (job.freelancerId?.isEmpty ?? true)) {
        actions.add(
          _JobAction(
            label: 'Accept',
            icon: Icons.handshake_outlined,
            onPressed: () {
              context.read<JobBloc>().add(AcceptJobRequested(job.id));
              telemetryService.record('job_accepted', properties: {'jobId': job.id});
            },
          ),
        );
      }
      actions.add(
        _JobAction(
          label: 'Chat',
          icon: Icons.chat_bubble_outline,
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.chat, arguments: job.id);
            telemetryService.record('job_chat_tapped', properties: {'jobId': job.id});
          },
        ),
      );
    }

    return actions;
  }

  void _openJobDetail(BuildContext context) {
    telemetryService.record('job_viewed', properties: {'jobId': job.id});
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: JobDetailScreen(jobId: job.id),
          );
        },
        transitionDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  String _formatRelative(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('d MMM').format(date);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      JobStatus.pending => theme.colorScheme.primary.withValues(alpha: 0.15),
      JobStatus.inProgress => theme.colorScheme.tertiary.withValues(alpha: 0.18),
      JobStatus.completed => theme.colorScheme.secondary.withValues(alpha: 0.2),
      JobStatus.cancelled => theme.colorScheme.error.withValues(alpha: 0.12),
    };
    final textColor = switch (status) {
      JobStatus.pending => theme.colorScheme.primary,
      JobStatus.inProgress => theme.colorScheme.tertiary,
      JobStatus.completed => theme.colorScheme.secondary,
      JobStatus.cancelled => theme.colorScheme.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _JobAction {
  const _JobAction({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}
