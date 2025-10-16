import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/job/job_bloc.dart';
import '../../controllers/job/job_event.dart';
import '../../controllers/job/job_state.dart';
import '../../models/job.dart';
import '../../utils/role_permissions.dart';
import '../../widgets/confirm_dialog.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<JobBloc>().add(LoadJobDetail(widget.jobId));
  }

  Future<void> _handleAccept(Job job) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Accept job',
      message: 'Are you sure you want to accept this job?',
      confirmLabel: 'Accept',
    );
    if (confirmed == true) {
      context.read<JobBloc>().add(AcceptJobRequested(job.id));
    }
  }

  Future<void> _handleComplete(Job job) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Mark complete',
      message: 'Confirm that this job has been completed?',
      confirmLabel: 'Complete',
    );
    if (confirmed == true) {
      context.read<JobBloc>().add(CompleteJobRequested(job.id));
    }
  }

  Future<void> _handlePay(Job job) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Pay now',
      message: 'Proceed with payment for this job?',
      confirmLabel: 'Pay now',
    );
    if (confirmed == true) {
      context.read<JobBloc>().add(PayJobRequested(job.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthBloc, AuthState>((bloc) => bloc.state);
    final userId = user is AuthAuthenticated ? user.user.id : null;
    final role = user is AuthAuthenticated ? user.user.role : 'guest';

    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: BlocConsumer<JobBloc, JobState>(
        listenWhen: (previous, current) =>
            previous.successMessage != current.successMessage ||
            previous.errorMessage != current.errorMessage,
        listener: (context, state) {
          final message = state.successMessage ?? state.errorMessage;
          if (message != null) {
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
          if (state.isLoadingDetail && state.selectedJob == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null && state.selectedJob == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(state.errorMessage ?? 'Failed to load job.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<JobBloc>().add(LoadJobDetail(widget.jobId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final job = state.selectedJob;
          if (job == null) {
            return const SizedBox.shrink();
          }

          final isPending = job.status == JobStatus.pending;
          final isInProgress = job.status == JobStatus.inProgress;
          final canAccept = isPending && role == UserRoles.freelancer;
          final canComplete = isInProgress &&
              ((role == UserRoles.freelancer && job.freelancerId == userId) ||
                  (role == UserRoles.client && job.clientId == userId));
          final canPay = job.status == JobStatus.completed &&
              role == UserRoles.client &&
              job.clientId == userId;

          return RefreshIndicator(
            onRefresh: () async {
              context.read<JobBloc>().add(LoadJobDetail(widget.jobId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(label: Text(_statusLabel(job.status))),
                      const SizedBox(width: 12),
                      Icon(Icons.location_on_outlined,
                          size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(job.location),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    job.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.category_outlined),
                      const SizedBox(width: 8),
                      Text(job.category),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_money_rounded),
                      const SizedBox(width: 8),
                      Text('Budget: \$${job.price.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule),
                      const SizedBox(width: 8),
                      Text(
                        'Created on ${DateFormat.yMMMd().add_jm().format(job.createdAt.toLocal())}',
                      ),
                    ],
                  ),
                  if (job.attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Attachments',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: job.attachments
                          .map(
                            (attachment) => ActionChip(
                              label: Text(attachment.split('/').last),
                              avatar: const Icon(Icons.attachment),
                              onPressed: () {},
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (canAccept)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: state.isSubmitting
                            ? null
                            : () => _handleAccept(job),
                        icon: const Icon(Icons.handshake_outlined),
                        label: const Text('Accept job'),
                      ),
                    ),
                  if (canComplete)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: state.isSubmitting
                            ? null
                            : () => _handleComplete(job),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark complete'),
                      ),
                    ),
                  if (canPay)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            state.isSubmitting ? null : () => _handlePay(job),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Pay now'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(JobStatus status) {
    switch (status) {
      case JobStatus.pending:
        return 'Pending';
      case JobStatus.inProgress:
        return 'In progress';
      case JobStatus.completed:
        return 'Completed';
    }
  }
}
