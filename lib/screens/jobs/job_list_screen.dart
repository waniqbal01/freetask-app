import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/job/job_state.dart';
import '../../models/job.dart';
import '../../widgets/app_button.dart';

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
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = _indexForType(widget.initialTab);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentTab();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
    });
    _loadCurrentTab();
  }

  void _loadCurrentTab() {
    final bloc = context.read<JobBloc>();
    final type = _typeForIndex(_tabController.index);
    bloc.add(LoadJobList(type));
  }

  JobListType _typeForIndex(int index) {
    switch (index) {
      case 1:
        return JobListType.mine;
      case 2:
        return JobListType.completed;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<JobBloc, JobState>(
      listenWhen: (previous, current) =>
          previous.successMessage != current.successMessage ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final message = state.successMessage ?? state.errorMessage;
        if (message != null && message.isNotEmpty) {
          final isError = state.errorMessage != null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor:
                  isError ? Theme.of(context).colorScheme.error : null,
            ),
          );
          context.read<JobBloc>().add(const ClearJobMessage());
        }
      },
      builder: (context, state) {
        final categorySet = <String>{};
        for (final jobs in state.jobLists.values) {
          for (final job in jobs) {
            if (job.category.isNotEmpty) {
              categorySet.add(job.category);
            }
          }
        }
        final categories = categorySet.toList()..sort();

        return Column(
          children: [
            if (widget.showCreateButton)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: AppButton(
                  label: 'Create Job',
                  icon: Icons.add,
                  onPressed: widget.onCreatePressed,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search jobs...',
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim());
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: const Text('All categories'),
                            ),
                            ...categories.map(
                              (category) => DropdownMenuItem<String?>(
                                value: category,
                                child: Text(category),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCategory = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: state.isLoadingList ? null : _loadCurrentTab,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Available'),
                Tab(text: 'My Jobs'),
                Tab(text: 'Completed'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _JobsTab(
                    type: JobListType.available,
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                  ),
                  _JobsTab(
                    type: JobListType.mine,
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                  ),
                  _JobsTab(
                    type: JobListType.completed,
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _JobsTab extends StatelessWidget {
  const _JobsTab({
    required this.type,
    required this.searchQuery,
    required this.selectedCategory,
  });

  final JobListType type;
  final String searchQuery;
  final String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JobBloc, JobState>(
      buildWhen: (previous, current) =>
          previous.jobLists != current.jobLists ||
          previous.isLoadingList != current.isLoadingList,
      builder: (context, state) {
        final jobs = state.jobLists[type] ?? const [];
        final filtered = jobs.where((job) {
          final matchesQuery = searchQuery.isEmpty ||
              job.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              job.description.toLowerCase().contains(searchQuery.toLowerCase());
          final matchesCategory = selectedCategory == null ||
              selectedCategory!.isEmpty ||
              job.category == selectedCategory;
          return matchesQuery && matchesCategory;
        }).toList();

        if (state.isLoadingList && jobs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (filtered.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<JobBloc>().add(LoadJobList(type));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                ),
                SizedBox(height: 12),
                Center(
                  child: Text('No jobs found for this filter.'),
                ),
                SizedBox(height: 120),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<JobBloc>().add(LoadJobList(type));
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final job = filtered[index];
              return _JobCard(job: job);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: filtered.length,
          ),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final Job job;

  Color _statusColor(BuildContext context) {
    switch (job.status) {
      case JobStatus.pending:
        return Colors.orange;
      case JobStatus.inProgress:
        return Theme.of(context).colorScheme.primary;
      case JobStatus.completed:
        return Colors.green;
    }
  }

  String _statusLabel() {
    switch (job.status) {
      case JobStatus.pending:
        return 'Pending';
      case JobStatus.inProgress:
        return 'In progress';
      case JobStatus.completed:
        return 'Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRoutes.jobDetail,
            arguments: job.id,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Chip(
                    label: Text(_statusLabel()),
                    backgroundColor: _statusColor(context).withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: _statusColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.category_outlined,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(job.category),
                  const SizedBox(width: 12),
                  Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(job.location),
                  const Spacer(),
                  Text(
                    '\$${job.price.toStringAsFixed(2)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
