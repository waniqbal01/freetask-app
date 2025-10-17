import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/routes.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/job/job_state.dart';
import '../../models/job.dart';
import '../../utils/role_permissions.dart';
import '../../widgets/confirm_dialog.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({
    super.key,
    this.initialTab = JobListType.available,
    this.onCreatePressed,
    this.showCreateButton = false,
  });

  final JobListType initialTab;
  final VoidCallback? onCreatePressed;
  final bool showCreateButton;

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  JobStatus? _statusFilter;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.index = _indexForType(widget.initialTab);
    _tabController.addListener(_handleTabChange);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<JobBloc>();
      bloc.add(JobTabChanged(widget.initialTab));
      bloc.add(JobListRequested(widget.initialTab));
      _syncFiltersWithState(bloc.state.feedFor(widget.initialTab));
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final type = _typeForIndex(_tabController.index);
    final bloc = context.read<JobBloc>();
    bloc.add(JobTabChanged(type));
    final feed = bloc.state.feedFor(type);
    _syncFiltersWithState(feed);
    bloc.add(JobListRequested(type));
  }

  void _syncFiltersWithState(JobFeedState feed) {
    setState(() {
      _statusFilter = feed.statusFilter;
      _categoryFilter = feed.categoryFilter;
      _updateSearchField(feed.searchQuery);
    });
  }

  void _updateSearchField(String value) {
    _searchController
      ..removeListener(_onSearchChanged)
      ..text = value
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: value.length),
      )
      ..addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      context.read<JobBloc>().add(
            JobSearchChanged(
              type: _typeForIndex(_tabController.index),
              query: query,
            ),
          );
    });
  }

  JobListType _typeForIndex(int index) {
    switch (index) {
      case 1:
        return JobListType.mine;
      case 2:
        return JobListType.completed;
      case 3:
        return JobListType.all;
      default:
        return JobListType.available;
    }
  }

  int _indexForType(JobListType type) {
    switch (type) {
      case JobListType.available:
        return 0;
      case JobListType.mine:
        return 1;
      case JobListType.completed:
        return 2;
      case JobListType.all:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JobBloc, JobState>(
      listenWhen: (previous, current) =>
          previous.successMessage != current.successMessage ||
          previous.errorMessage != current.errorMessage ||
          previous.notification != current.notification,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.errorMessage != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else if (state.successMessage != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(state.successMessage!)),
          );
        }
        final alert = state.notification;
        if (alert != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(alert.message),
            ),
          );
        }
        if (state.errorMessage != null ||
            state.successMessage != null ||
            state.notification != null) {
          context.read<JobBloc>().add(const ClearJobMessage());
        }
      },
      builder: (context, state) {
        final currentFeed = state.feedFor(_typeForIndex(_tabController.index));
        final categories = state.categories.toList()..sort((a, b) => a.compareTo(b));
        final textTheme = Theme.of(context).textTheme;
        final filterStyle = GoogleFonts.poppins(fontWeight: FontWeight.w500);

        return Column(
          children: [
            if (widget.showCreateButton)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: FilledButton.icon(
                  onPressed: widget.onCreatePressed,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Create Job'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search jobs by title, category or description',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => _onSearchChanged(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<JobStatus?>(
                          value: _statusFilter,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: filterStyle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<JobStatus?>(
                              value: null,
                              child: Text('All statuses'),
                            ),
                            ...JobStatus.values.map(
                              (status) => DropdownMenuItem<JobStatus?>(
                                value: status,
                                child: Text(status.label),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _statusFilter = value);
                            context.read<JobBloc>().add(
                                  JobFilterChanged(
                                    type: _typeForIndex(_tabController.index),
                                    status: value,
                                    category: _categoryFilter,
                                  ),
                                );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _categoryFilter,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            labelStyle: filterStyle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All categories'),
                            ),
                            ...categories.map(
                              (category) => DropdownMenuItem<String?>(
                                value: category,
                                child: Text(category),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _categoryFilter = value);
                            context.read<JobBloc>().add(
                                  JobFilterChanged(
                                    type: _typeForIndex(_tabController.index),
                                    status: _statusFilter,
                                    category: value,
                                  ),
                                );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: () {
                          context.read<JobBloc>().add(
                                JobListRequested(
                                  _typeForIndex(_tabController.index),
                                  refresh: true,
                                ),
                              );
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Open'),
                Tab(text: 'In Progress'),
                Tab(text: 'Completed'),
                Tab(text: 'All'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _JobsTab(type: JobListType.available),
                  _JobsTab(type: JobListType.mine),
                  _JobsTab(type: JobListType.completed),
                  _JobsTab(type: JobListType.all),
                ],
              ),
            ),
            if (currentFeed.isLoadingInitial)
              const LinearProgressIndicator(minHeight: 2),
          ],
        );
      },
    );
  }
}

class _JobsTab extends StatefulWidget {
  const _JobsTab({required this.type});

  final JobListType type;

  @override
  State<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<_JobsTab> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<JobBloc>().add(JobLoadMoreRequested(widget.type));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JobBloc, JobState>(
      buildWhen: (previous, current) =>
          previous.feedFor(widget.type) != current.feedFor(widget.type),
      builder: (context, state) {
        final feed = state.feedFor(widget.type);
        final authState = context.watch<AuthBloc>().state;
        final isAuthenticated =
            authState.status == AuthStatus.authenticated &&
                authState is AuthAuthenticated;
        final userId = isAuthenticated ? authState.user.id : null;
        final role = isAuthenticated ? authState.user.role : null;

        if (feed.isLoadingInitial && feed.jobs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (feed.errorMessage != null && feed.jobs.isEmpty) {
          return _EmptyState(
            icon: Icons.error_outline,
            title: 'Unable to load jobs',
            message: feed.errorMessage!,
            actionLabel: 'Retry',
            onAction: () => context
                .read<JobBloc>()
                .add(JobListRequested(widget.type, refresh: true)),
          );
        }

        if (feed.jobs.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No jobs yet',
            message: 'Try adjusting your filters or check back later.',
            onRefresh: () => context
                .read<JobBloc>()
                .add(JobListRequested(widget.type, refresh: true)),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context
                .read<JobBloc>()
                .add(JobListRequested(widget.type, refresh: true));
          },
          child: ListView.separated(
            controller: _controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemBuilder: (context, index) {
              if (index >= feed.jobs.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final job = feed.jobs[index];
              return _JobCard(
                job: job,
                role: role,
                currentUserId: userId,
                listType: widget.type,
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: feed.jobs.length + (feed.isLoadingMore ? 1 : 0),
          ),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.role,
    required this.currentUserId,
    required this.listType,
  });

  final Job job;
  final String? role;
  final String? currentUserId;
  final JobListType listType;

  Color _statusColor(BuildContext context) {
    switch (job.status) {
      case JobStatus.pending:
        return Colors.orange;
      case JobStatus.inProgress:
        return const Color(0xFF0057B8);
      case JobStatus.completed:
        return Colors.green;
      case JobStatus.cancelled:
        return Colors.redAccent;
    }
  }

  Future<void> _handlePrimaryAction(BuildContext context) async {
    final bloc = context.read<JobBloc>();
    if (role == UserRoles.freelancer && job.status == JobStatus.pending) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Accept job',
        message: 'Are you sure you want to accept "${job.title}"?',
        confirmLabel: 'Accept',
      );
      if (confirmed == true) {
        bloc.add(AcceptJobRequested(job.id));
      }
    } else if (job.status == JobStatus.inProgress &&
        ((role == UserRoles.client && job.clientId == currentUserId) ||
            (role == UserRoles.freelancer && job.freelancerId == currentUserId))) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Mark as complete',
        message: 'Confirm that this job has been completed?',
        confirmLabel: 'Complete',
      );
      if (confirmed == true) {
        bloc.add(CompleteJobRequested(job.id));
      }
    } else if (role == UserRoles.client &&
        (job.status == JobStatus.pending || job.status == JobStatus.inProgress) &&
        job.clientId == currentUserId) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Cancel job',
        message: 'Do you really want to cancel "${job.title}"?',
        confirmLabel: 'Cancel job',
      );
      if (confirmed == true) {
        bloc.add(CancelJobRequested(job.id));
      }
    } else {
      Navigator.of(context).pushNamed(AppRoutes.jobDetail, arguments: job.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final titleStyle = GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );

    final canAccept =
        role == UserRoles.freelancer && job.status == JobStatus.pending;
    final canComplete = job.status == JobStatus.inProgress &&
        ((role == UserRoles.freelancer && job.freelancerId == currentUserId) ||
            (role == UserRoles.client && job.clientId == currentUserId));
    final canCancel = role == UserRoles.client &&
        (job.status == JobStatus.pending || job.status == JobStatus.inProgress) &&
        job.clientId == currentUserId;

    final actionLabel = canAccept
        ? 'Accept Job'
        : canComplete
            ? 'Mark Complete'
            : canCancel
                ? 'Cancel Job'
                : 'View Details';

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.jobDetail, arguments: job.id),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(job.title, style: titleStyle),
                  ),
                  Chip(
                    label: Text(job.status.label),
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: _statusColor(context),
                    ),
                    backgroundColor: _statusColor(context).withValues(alpha: 0.12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.category_outlined,
                    label: job.category.isEmpty ? 'Uncategorised' : job.category,
                  ),
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    label: job.location.isEmpty ? 'Remote' : job.location,
                  ),
                  _InfoChip(
                    icon: Icons.attach_money,
                    label: '\$${job.price.toStringAsFixed(2)}',
                  ),
                ],
              ),
              if (job.freelancerName != null || job.clientName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      if (job.clientName != null)
                        Expanded(
                          child: _InfoRow(
                            icon: Icons.person_outline,
                            label: 'Client',
                            value: job.clientName!,
                          ),
                        ),
                      if (job.freelancerName != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoRow(
                            icon: Icons.engineering_outlined,
                            label: 'Freelancer',
                            value: job.freelancerName!,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => _handlePrimaryAction(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0057B8).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFF0057B8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 12)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          '$label:',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onRefresh,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRefresh,
                child: const Text('Refresh'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
