import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/chat/chat_list_bloc.dart';
import '../../controllers/chat/chat_list_event.dart';
import '../../controllers/dashboard/dashboard_metrics_cubit.dart' as metrics;
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/job/job_state.dart';
import '../../controllers/nav/role_nav_cubit.dart';
import '../../controllers/profile/profile_bloc.dart';
import '../../models/job_list_type.dart';
import '../../services/storage_service.dart';
import '../../utils/role_permissions.dart';
import '../../widgets/app_bottom_nav.dart';
import '../chat/chat_view.dart';
import '../profile/profile_view.dart';
import 'jobs_tab_view.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    this.initialTarget = RoleNavTarget.home,
  });

  static const routeName = AppRoutes.dashboard;

  final RoleNavTarget initialTarget;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  RoleNavTarget? _activeTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navCubit = context.read<RoleNavCubit>();
      final tabs = navCubit.state.tabs;
      final initialIndex = tabs.indexWhere((tab) => tab.target == widget.initialTarget);
      if (initialIndex >= 0 && initialIndex != navCubit.state.index) {
        navCubit.setIndex(initialIndex);
      }
      final target = tabs[(initialIndex >= 0 ? initialIndex : navCubit.state.index)].target;
      _activeTarget = target;
      _onTargetSelected(target);
    });
  }

  void _onTargetSelected(RoleNavTarget target) {
    setState(() => _activeTarget = target);
    switch (target) {
      case RoleNavTarget.home:
        break;
      case RoleNavTarget.jobs:
        final jobBloc = context.read<JobBloc>();
        jobBloc.add(const JobTabChanged(JobListType.available));
        jobBloc.add(const JobListRequested(JobListType.available));
        break;
      case RoleNavTarget.chat:
        context.read<ChatListBloc>().add(const LoadChatThreads());
        break;
      case RoleNavTarget.profile:
        context.read<ProfileBloc>().add(const ProfileStarted());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoleNavCubit, RoleNavState>(
      listener: (context, state) {
        final target = state.tabs[state.index].target;
        if (_activeTarget != target) {
          _onTargetSelected(target);
        }
      },
      child: BlocListener<JobBloc, JobState>(
        listenWhen: (previous, current) =>
            previous.errorMessage != current.errorMessage ||
            previous.successMessage != current.successMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          } else if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.successMessage!)),
            );
          }
        },
        child: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              previous.status != current.status,
          listener: (context, state) {
            if (state is AuthUnauthenticated && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You have been logged out.')),
              );
            }
          },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: BlocBuilder<RoleNavCubit, RoleNavState>(
              builder: (context, navState) {
                final pages = navState.tabs
                    .map((tab) => _PageWrapper(target: tab.target))
                    .toList(growable: false);
                return IndexedStack(
                  index: navState.index,
                  children: pages,
                );
              },
            ),
          ),
          floatingActionButton: _activeTarget == RoleNavTarget.jobs
              ? const _PostJobButton()
              : null,
          bottomNavigationBar: AppBottomNav(
            onSelected: _onTargetSelected,
          ),
        ),
      ),
      ),
    );
  }
}

class _PageWrapper extends StatelessWidget {
  const _PageWrapper({required this.target});

  final RoleNavTarget target;

  @override
  Widget build(BuildContext context) {
    switch (target) {
      case RoleNavTarget.home:
        return const _DashboardOverview();
      case RoleNavTarget.jobs:
        return const JobsTabView();
      case RoleNavTarget.chat:
        return const ChatView();
      case RoleNavTarget.profile:
        return const ProfileView();
    }
  }
}

class _PostJobButton extends StatelessWidget {
  const _PostJobButton();

  @override
  Widget build(BuildContext context) {
    final storage = RepositoryProvider.of<StorageService>(context);
    final role = storage.role ?? storage.getUser()?.role;
    if (!RolePermissions.roleCanPostJob(role)) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton.extended(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job posting is coming soon.'),
          ),
        );
      },
      icon: const Icon(Icons.add),
      label: const Text('Post Job'),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        context.read<JobBloc>().add(const JobListRequested(JobListType.available, refresh: true));
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s snapshot',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track active work, earnings, and conversations at a glance.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            BlocBuilder<metrics.DashboardMetricsCubit, metrics.DashboardMetricsState>(
              builder: (context, state) {
                if (state.loading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final metricsList = state.metrics.isNotEmpty
                    ? state.metrics
                    : const [
                        metrics.DashboardMetricData(
                          label: 'Active Jobs',
                          value: '0',
                          icon: 'work_outline',
                        ),
                        metrics.DashboardMetricData(
                          label: 'Earnings',
                          value: '0',
                          icon: 'payments_outlined',
                        ),
                        metrics.DashboardMetricData(
                          label: 'Chats',
                          value: '0',
                          icon: 'chat_bubble_outline',
                        ),
                      ];

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: metricsList
                      .take(6)
                      .map(
                        (metric) => _MetricCard(
                          data: metric,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final metrics.DashboardMetricData data;

  IconData _iconData(String icon) {
    switch (icon) {
      case 'work_outline':
        return Icons.work_outline;
      case 'payments_outlined':
        return Icons.payments_outlined;
      case 'chat_bubble_outline':
        return Icons.chat_bubble_outline;
      case 'dashboard_outlined':
        return Icons.dashboard_outlined;
      case 'explore_outlined':
        return Icons.explore_outlined;
      case 'support_agent_outlined':
        return Icons.support_agent;
      case 'people_alt_outlined':
        return Icons.people_alt_outlined;
      case 'handshake_outlined':
        return Icons.handshake_outlined;
      case 'verified_outlined':
        return Icons.verified_outlined;
      case 'account_balance_wallet_outlined':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.insights_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: MediaQuery.of(context).size.width / 2 - 24,
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _iconData(data.icon),
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
