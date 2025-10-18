import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../models/job.dart';
import '../../models/job_list_type.dart';
import '../../services/storage_service.dart';
import '../../utils/role_permissions.dart';
import '../job/job_bloc.dart';
import '../job/job_state.dart';

/// Aggregates dashboard metrics derived from the job feeds so that consumers can
/// stay declarative. The cubit listens to [JobBloc] updates and recalculates
/// metrics whenever jobs change, ensuring the UI reflects the latest
/// information without additional API requests.
class DashboardMetricsCubit extends Cubit<DashboardMetricsState> {
  DashboardMetricsCubit(this._jobBloc, this._storage)
      : super(const DashboardMetricsState.loading()) {
    _subscription = _jobBloc.stream.listen(_onJobState);
    _onJobState(_jobBloc.state);
  }

  final JobBloc _jobBloc;
  final StorageService _storage;
  StreamSubscription<JobState>? _subscription;

  void updateRole(String role) {
    if (state.role == role) return;
    _emitForRole(role, _jobBloc.state);
  }

  void _onJobState(JobState jobState) {
    final resolvedRole = state.role ??
        _storage.role ??
        _storage.getUser()?.role ??
        UserRoles.defaultRole;
    _emitForRole(resolvedRole, jobState);
  }

  void _emitForRole(String role, JobState jobState) {
    final metrics = _buildMetrics(role, jobState);
    emit(
      DashboardMetricsState(
        role: role,
        metrics: metrics,
        loading: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  List<DashboardMetricData> _buildMetrics(String role, JobState state) {
    final user = _storage.getUser();
    final feeds = state.feeds;
    final myJobs = feeds[JobListType.mine]?.jobs ?? const [];
    final availableJobs = feeds[JobListType.available]?.jobs ?? const [];
    final completedJobs = feeds[JobListType.completed]?.jobs ?? const [];
    final allJobsFeed = feeds[JobListType.all]?.jobs ?? const [];
    final allJobs = {
      ...availableJobs,
      ...myJobs,
      ...completedJobs,
      ...allJobsFeed,
    }.toList();

    if (role == UserRoles.admin ||
        role == UserRoles.manager ||
        role == UserRoles.support) {
      final users = <String>{};
      final revenue = allJobs
          .where((job) => job.status == JobStatus.completed)
          .fold<double>(0, (previous, job) => previous + job.price);
      for (final job in allJobs) {
        if (job.clientId.isNotEmpty) users.add(job.clientId);
        if ((job.freelancerId ?? '').isNotEmpty) {
          users.add(job.freelancerId!);
        }
      }
      final activeFreelancers = allJobs
          .where((job) =>
              job.freelancerId != null && job.freelancerId!.isNotEmpty)
          .map((job) => job.freelancerId)
          .whereType<String>()
          .toSet()
          .length;
      return [
        DashboardMetricData(
          label: 'Users',
          value: users.length.toString(),
          icon: 'people_alt_outlined',
        ),
        DashboardMetricData(
          label: 'Jobs',
          value: allJobs.length.toString(),
          icon: 'work_outline',
        ),
        DashboardMetricData(
          label: 'Revenue',
          value: _formatCurrency(revenue),
          icon: 'payments_outlined',
        ),
        DashboardMetricData(
          label: 'Active Freelancers',
          value: activeFreelancers.toString(),
          icon: 'support_agent_outlined',
        ),
      ];
    }

    if (role == UserRoles.client) {
      final clientId = user?.id ?? '';
      final activeJobs = myJobs
          .where((job) =>
              job.clientId == clientId &&
              (job.status == JobStatus.pending ||
                  job.status == JobStatus.inProgress))
          .length;
      final completed = completedJobs
          .where((job) => job.clientId == clientId)
          .length;
      final totalSpent = completedJobs
          .where((job) => job.clientId == clientId)
          .fold<double>(0, (previous, job) => previous + job.price);
      return [
        DashboardMetricData(
          label: 'Active Jobs',
          value: activeJobs.toString(),
          icon: 'play_circle_outline',
        ),
        DashboardMetricData(
          label: 'Completed',
          value: completed.toString(),
          icon: 'verified_outlined',
        ),
        DashboardMetricData(
          label: 'Total Spent',
          value: _formatCurrency(totalSpent),
          icon: 'account_balance_wallet_outlined',
        ),
      ];
    }

    // Default to freelancer metrics.
    final freelancerId = user?.id ?? '';
    final available = availableJobs.length;
    final accepted = myJobs
        .where((job) => job.freelancerId == freelancerId)
        .length;
    final earnings = completedJobs
        .where((job) => job.freelancerId == freelancerId)
        .fold<double>(0, (previous, job) => previous + job.price);
    return [
      DashboardMetricData(
        label: 'Available',
        value: available.toString(),
        icon: 'explore_outlined',
      ),
      DashboardMetricData(
        label: 'Accepted',
        value: accepted.toString(),
        icon: 'handshake_outlined',
      ),
      DashboardMetricData(
        label: 'Earnings',
        value: _formatCurrency(earnings),
        icon: 'attach_money',
      ),
    ];
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

class DashboardMetricsState extends Equatable {
  const DashboardMetricsState({
    required this.metrics,
    required this.loading,
    required this.role,
    required this.updatedAt,
  });

  const DashboardMetricsState.loading()
      : metrics = const [],
        loading = true,
        role = null,
        updatedAt = null;

  final List<DashboardMetricData> metrics;
  final bool loading;
  final String? role;
  final DateTime? updatedAt;

  DashboardMetricsState copyWith({
    List<DashboardMetricData>? metrics,
    bool? loading,
    String? role,
    DateTime? updatedAt,
  }) {
    return DashboardMetricsState(
      metrics: metrics ?? this.metrics,
      loading: loading ?? this.loading,
      role: role ?? this.role,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [metrics, loading, role, updatedAt];
}

class DashboardMetricData extends Equatable {
  const DashboardMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final String icon;

  @override
  List<Object?> get props => [label, value, icon];
}
