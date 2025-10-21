import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../controllers/bid/bid_cubit.dart';
import '../../controllers/bid/bid_state.dart';
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/job/job_state.dart';
import '../../models/bid.dart';
import '../../models/job.dart';
import '../../services/bid_service.dart';
import '../../widgets/job_card.dart';

class JobDetailView extends StatefulWidget {
  const JobDetailView({super.key, required this.jobId});

  static const routeName = '/job-detail';

  final String jobId;

  @override
  State<JobDetailView> createState() => _JobDetailViewState();
}

class _JobDetailViewState extends State<JobDetailView> {
  bool _reviewDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobBloc>().add(LoadJobDetail(widget.jobId, force: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.jobId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Detail')),
        body: Center(
          child: Text(
            'Job not found.',
            style: theme.textTheme.titleMedium,
          ),
        ),
      );
    }
    return BlocListener<JobBloc, JobState>(
      listenWhen: (previous, current) =>
          previous.reviewPromptJob != current.reviewPromptJob ||
          previous.errorMessage != current.errorMessage ||
          previous.successMessage != current.successMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.successMessage!)),
          );
        }
        final prompt = state.reviewPromptJob;
        if (prompt != null && prompt.id == widget.jobId && !_reviewDialogShown) {
          _reviewDialogShown = true;
          _showReviewDialog(prompt);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Job Detail'),
        ),
        body: BlocBuilder<JobBloc, JobState>(
          builder: (context, state) {
            if (state.isLoadingDetail || state.selectedJob == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final job = state.selectedJob!;
            return MultiBlocProvider(
              providers: [
                BlocProvider<BidCubit>(
                  create: (context) => BidCubit(
                    RepositoryProvider.of<BidService>(context),
                    jobId: job.id,
                  )..load(),
                ),
              ],
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    JobCard(job: job),
                    const SizedBox(height: 16),
                    _JobStatusSection(job: job),
                    const SizedBox(height: 24),
                    Text(
                      'Description',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    _BidsSection(jobId: job.id),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showReviewDialog(Job job) async {
    final controller = TextEditingController();
    double rating = 5;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Rate this project'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How was your experience completing "${job.title}"?'),
                  const SizedBox(height: 16),
                  Slider(
                    value: rating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: rating.toStringAsFixed(1),
                    onChanged: (value) => setState(() => rating = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Leave a short review (optional)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.read<JobBloc>().add(
                          SubmitJobReviewRequested(
                            jobId: job.id,
                            rating: rating,
                            comment: controller.text.trim(),
                          ),
                        );
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _JobStatusSection extends StatelessWidget {
  const _JobStatusSection({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = job.status.statusColor(theme);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.adjust, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  job.status.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: job.status.progress,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusChip(label: 'Budget', value: '\$${job.price.toStringAsFixed(0)}'),
                _StatusChip(label: 'Location', value: job.location),
                if (job.freelancerName != null && job.freelancerName!.isNotEmpty)
                  _StatusChip(label: 'Freelancer', value: job.freelancerName!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BidsSection extends StatelessWidget {
  const _BidsSection({required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<BidCubit, BidState>(
      builder: (context, state) {
        if (state.status == BidViewStatus.loading && state.bids.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == BidViewStatus.error && state.bids.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bids',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(state.errorMessage ?? 'Unable to load bids.'),
            ],
          );
        }
        final bids = state.visibleBids;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bids (${state.bids.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                DropdownButton<BidStatusFilter>(
                  value: state.filter,
                  underline: const SizedBox.shrink(),
                  onChanged: (filter) {
                    if (filter != null) {
                      context.read<BidCubit>().changeFilter(filter);
                    }
                  },
                  items: BidStatusFilter.values
                      .map(
                        (filter) => DropdownMenuItem(
                          value: filter,
                          child: Text(filter.name.toUpperCase()),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (bids.isEmpty)
              Text('No bids yet for this job.', style: theme.textTheme.bodyMedium)
            else
              ...bids.map(
                (bid) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(bid.bidder.name.isEmpty ? 'Anonymous' : bid.bidder.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\$${bid.amount.toStringAsFixed(0)}'),
                        const SizedBox(height: 4),
                        Text(
                          bid.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: Text(bid.status.label),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
