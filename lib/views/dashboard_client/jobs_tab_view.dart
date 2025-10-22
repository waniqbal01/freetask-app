import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/job/job_state.dart';
import '../../models/job.dart';
import '../../models/job_list_type.dart';
import '../../widgets/job_card.dart';

class JobsTabView extends StatefulWidget {
  const JobsTabView({super.key});

  @override
  State<JobsTabView> createState() => _JobsTabViewState();
}

class _JobsTabViewState extends State<JobsTabView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<JobBloc>();
      final feed = bloc.state.feedFor(JobListType.available);
      if (!feed.initialized) {
        bloc.add(const JobListRequested(JobListType.available));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final bloc = context.read<JobBloc>();
    final feed = bloc.state.feedFor(JobListType.available);
    if (!feed.hasMore || feed.isLoadingMore || feed.isLoadingInitial) {
      return;
    }
    final threshold = _scrollController.position.maxScrollExtent - 120;
    if (_scrollController.position.pixels >= threshold) {
      bloc.add(const JobLoadMoreRequested(JobListType.available));
    }
  }

  Future<void> _refresh() async {
    context
        .read<JobBloc>()
        .add(const JobListRequested(JobListType.available, refresh: true));
  }

  void _onStatusSelected(JobStatus? status) {
    context.read<JobBloc>().add(
          JobFilterChanged(
            type: JobListType.available,
            status: status,
            clearBudget: true,
            clearLocation: true,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<JobBloc, JobState>(
      builder: (context, state) {
        final feed = state.feedFor(JobListType.available);
        final jobs = feed.jobs;
        final status = feed.statusFilter;
        final filters = [
          const _StatusFilter(label: 'All', status: null),
          const _StatusFilter(label: '🟢 Open', status: JobStatus.pending),
          const _StatusFilter(label: '🟡 In Progress', status: JobStatus.inProgress),
          const _StatusFilter(label: '🔵 Completed', status: JobStatus.completed),
        ];

        if (feed.isLoadingInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Browse jobs',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Find work that matches your skills or follow up on ongoing projects.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final filter in filters)
                    ChoiceChip(
                      label: Text(filter.label),
                      selected: status == filter.status,
                      onSelected: (_) => _onStatusSelected(filter.status),
                      selectedColor:
                          theme.colorScheme.primary.withOpacity(0.15),
                      labelStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: status == filter.status
                            ? theme.colorScheme.primary
                            : Colors.grey.shade600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: jobs.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.work_outline,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No jobs yet',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Check back later or adjust your filters.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 120),
                          itemBuilder: (context, index) {
                            final job = jobs[index];
                            return JobCard(
                              job: job,
                              onTap: () => Navigator.of(context).pushNamed(
                                AppRoutes.jobDetail,
                                arguments: job.id,
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemCount: jobs.length,
                        ),
                ),
              ),
              if (feed.isLoadingMore) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusFilter {
  const _StatusFilter({required this.label, required this.status});

  final String label;
  final JobStatus? status;
}
