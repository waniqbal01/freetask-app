import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Future<void> _handleAction(
    BuildContext context,
    Job job,
    JobActionType action,
  ) async {
    final bloc = context.read<JobBloc>();
    switch (action) {
      case JobActionType.accept:
        final confirmed = await showConfirmDialog(
          context,
          title: 'Accept job',
          message: 'Accept "${job.title}" and start working?',
          confirmLabel: 'Accept',
        );
        if (confirmed == true) {
          bloc.add(AcceptJobRequested(job.id));
        }
        break;
      case JobActionType.complete:
        final confirmed = await showConfirmDialog(
          context,
          title: 'Mark as complete',
          message: 'Confirm that this job has been completed?',
          confirmLabel: 'Complete',
        );
        if (confirmed == true) {
          bloc.add(CompleteJobRequested(job.id));
        }
        break;
      case JobActionType.cancel:
        final confirmed = await showConfirmDialog(
          context,
          title: 'Cancel job',
          message: 'Do you really want to cancel this job?',
          confirmLabel: 'Cancel job',
        );
        if (confirmed == true) {
          bloc.add(CancelJobRequested(job.id));
        }
        break;
      case JobActionType.pay:
        final confirmed = await showConfirmDialog(
          context,
          title: 'Release payment',
          message: 'Proceed with payment for this job?',
          confirmLabel: 'Pay now',
        );
        if (confirmed == true) {
          bloc.add(PayJobRequested(job.id));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    final role = authState is AuthAuthenticated ? authState.user.role : 'guest';

    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: BlocConsumer<JobBloc, JobState>(
        listenWhen: (previous, current) =>
            previous.successMessage != current.successMessage ||
            previous.errorMessage != current.errorMessage ||
            previous.notification != current.notification,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          final message = state.successMessage ?? state.errorMessage;
          if (message != null) {
            final isError = state.errorMessage != null;
            messenger.showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor:
                    isError ? Theme.of(context).colorScheme.error : null,
              ),
            );
          }
          final alert = state.notification;
          if (alert != null) {
            messenger.showSnackBar(
              SnackBar(content: Text(alert.message)),
            );
          }
          if (state.errorMessage != null ||
              state.successMessage != null ||
              state.notification != null) {
            context.read<JobBloc>().add(const ClearJobMessage());
          }
        },
        builder: (context, state) {
          if (state.isLoadingDetail && state.selectedJob == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.errorMessage != null && state.selectedJob == null) {
            return _ErrorView(
              errorMessage: state.errorMessage!,
              onRetry: () =>
                  context.read<JobBloc>().add(LoadJobDetail(widget.jobId)),
            );
          }

          final job = state.selectedJob;
          if (job == null) {
            return const SizedBox.shrink();
          }

          final actions = _availableActions(job, userId, role);

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<JobBloc>()
                  .add(LoadJobDetail(widget.jobId, force: true));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatusChip(status: job.status),
                      _IconLabel(
                        icon: Icons.schedule,
                        label:
                            'Created ${DateFormat.yMMMMd().add_jm().format(job.createdAt)}',
                      ),
                      if (job.updatedAt != null)
                        _IconLabel(
                          icon: Icons.update,
                          label:
                              'Updated ${DateFormat.yMMMd().add_jm().format(job.updatedAt!)}',
                        ),
                      _IconLabel(
                        icon: Icons.location_on_outlined,
                        label: job.location.isEmpty ? 'Remote' : job.location,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: 'Description',
                    child: Text(
                      job.description,
                      style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Summary',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: job.category.isEmpty ? 'Uncategorised' : job.category,
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          icon: Icons.attach_money,
                          label: 'Budget',
                          value: '\$${job.price.toStringAsFixed(2)}',
                        ),
                        if (job.clientName != null) ...[
                          const SizedBox(height: 12),
                          _SummaryRow(
                            icon: Icons.person_outline,
                            label: 'Client',
                            value: job.clientName!,
                          ),
                        ],
                        if (job.freelancerName != null) ...[
                          const SizedBox(height: 12),
                          _SummaryRow(
                            icon: Icons.engineering_outlined,
                            label: 'Freelancer',
                            value: job.freelancerName!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (job.attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Attachments',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: job.attachments
                            .map(
                              (attachment) => ActionChip(
                                avatar: const Icon(Icons.attachment),
                                label: Text(attachment.name),
                                onPressed: () {},
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (actions.isEmpty)
                    Text(
                      'No actions available for your role at this stage.',
                      style: GoogleFonts.poppins(fontSize: 14),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: actions
                          .map(
                            (action) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: FilledButton.icon(
                                icon: Icon(action.icon),
                                label: Text(action.label),
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => _handleAction(
                                          context,
                                          job,
                                          action.type,
                                        ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_JobAction> _availableActions(Job job, String? userId, String role) {
    final actions = <_JobAction>[];
    final isClient = role == UserRoles.client && job.clientId == userId;
    final isFreelancer = role == UserRoles.freelancer && job.freelancerId == userId;

    if (role == UserRoles.freelancer && job.status == JobStatus.pending) {
      actions.add(
        const _JobAction(
          label: 'Accept job',
          icon: Icons.handshake_outlined,
          type: JobActionType.accept,
        ),
      );
    }

    if ((isClient || isFreelancer) && job.status == JobStatus.inProgress) {
      actions.add(
        const _JobAction(
          label: 'Mark as complete',
          icon: Icons.check_circle_outline,
          type: JobActionType.complete,
        ),
      );
    }

    if (isClient &&
        (job.status == JobStatus.pending || job.status == JobStatus.inProgress)) {
      actions.add(
        const _JobAction(
          label: 'Cancel job',
          icon: Icons.cancel_outlined,
          type: JobActionType.cancel,
        ),
      );
    }

    if (isClient && job.status == JobStatus.completed) {
      actions.add(
        const _JobAction(
          label: 'Release payment',
          icon: Icons.payments_outlined,
          type: JobActionType.pay,
        ),
      );
    }

    return actions;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 6,
      ),
      label: Text(status.label),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Color _statusColor(JobStatus status) {
    switch (status) {
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
}

class _JobAction {
  const _JobAction({
    required this.label,
    required this.icon,
    required this.type,
  });

  final String label;
  final IconData icon;
  final JobActionType type;
}

enum JobActionType { accept, complete, cancel, pay }

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.errorMessage, required this.onRetry});

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
