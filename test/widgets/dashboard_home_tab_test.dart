import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:freetask_app/controllers/auth/auth_state.dart';
import 'package:freetask_app/controllers/dashboard/dashboard_metrics_cubit.dart';
import 'package:freetask_app/controllers/job/job_bloc.dart';
import 'package:freetask_app/controllers/job/job_event.dart';
import 'package:freetask_app/controllers/job/job_state.dart';
import 'package:freetask_app/models/job.dart';
import 'package:freetask_app/models/user.dart';
import 'package:freetask_app/screens/dashboard/dashboard_screen.dart';
import 'package:freetask_app/services/telemetry_service.dart';
import 'package:freetask_app/utils/role_permissions.dart';

class _MockJobBloc extends MockBloc<JobEvent, JobState> implements JobBloc {}

class _MockMetricsCubit extends MockCubit<DashboardMetricsState>
    implements DashboardMetricsCubit {}

void main() {
  setUpAll(() {
    registerFallbackValue(const JobTabChanged(JobListType.mine));
    registerFallbackValue(const JobListRequested(JobListType.mine));
    registerFallbackValue(const JobListRequested(JobListType.available));
    registerFallbackValue(const JobSearchChanged(type: JobListType.mine, query: ''));
    registerFallbackValue(const JobSearchChanged(type: JobListType.available, query: ''));
    registerFallbackValue(const JobFilterChanged(type: JobListType.mine));
    registerFallbackValue(const JobFilterChanged(type: JobListType.available));
    registerFallbackValue(const JobLoadMoreRequested(JobListType.mine));
    registerFallbackValue(const JobLoadMoreRequested(JobListType.available));
    registerFallbackValue(const AcceptJobRequested('job'));
    registerFallbackValue(const CompleteJobRequested('job'));
    registerFallbackValue(const PayJobRequested('job'));
  });

  final baseUser = User(
    id: 'user-1',
    name: 'Alicia',
    email: 'alicia@example.com',
    role: UserRoles.client,
    avatarUrl: null,
    bio: null,
    location: 'Kuala Lumpur',
    phoneNumber: null,
    verified: true,
  );

  group('DashboardHomeTab metrics', () {
    testWidgets('renders metric cards with provided values', (tester) async {
      final jobBloc = _MockJobBloc();
      final metricsCubit = _MockMetricsCubit();

      const feed = JobFeedState(initialized: true, jobs: []);
      final jobState = JobState(feeds: {JobListType.mine: feed});
      when(() => jobBloc.state).thenReturn(jobState);
      whenListen(jobBloc, Stream<JobState>.value(jobState));

      final metricsState = DashboardMetricsState(
        metrics: const [
          DashboardMetricData(label: 'Active Jobs', value: '5', icon: Icons.work_outline),
          DashboardMetricData(label: 'Completed', value: '12', icon: Icons.verified_outlined),
          DashboardMetricData(label: 'Total Spent', value: 'RM5000', icon: Icons.payments_outlined),
        ],
        loading: false,
        role: UserRoles.client,
        updatedAt: DateTime.now(),
      );
      when(() => metricsCubit.state).thenReturn(metricsState);
      whenListen(metricsCubit, Stream<DashboardMetricsState>.value(metricsState));

      final telemetryDir = Directory.systemTemp.createTempSync('telemetry_test');
      addTearDown(() => telemetryDir.deleteSync(recursive: true));
      final telemetry = TelemetryService(directory: telemetryDir);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<JobBloc>.value(value: jobBloc),
              BlocProvider<DashboardMetricsCubit>.value(value: metricsCubit),
            ],
            child: DashboardHomeTab(
              authState: AuthAuthenticated(baseUser),
              role: UserRoles.client,
              telemetryService: telemetry,
              listType: JobListType.mine,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Active Jobs'), findsOneWidget);
      expect(find.text('5'), findsWidgets);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Total Spent'), findsOneWidget);
    });
  });

  group('DashboardHomeTab job feed', () {
    testWidgets('shows contextual actions for freelancers', (tester) async {
      final jobBloc = _MockJobBloc();
      final metricsCubit = _MockMetricsCubit();

      final job = Job(
        id: 'job-1',
        title: 'Design landing page',
        description: 'Create a responsive landing page',
        price: 750,
        category: 'Design',
        location: 'Remote',
        status: JobStatus.pending,
        clientId: 'client-1',
        clientName: 'Marie',
        freelancerId: null,
        freelancerName: null,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final feed = JobFeedState(jobs: [job], initialized: true);
      final jobState = JobState(feeds: {JobListType.available: feed});
      when(() => jobBloc.state).thenReturn(jobState);
      whenListen(jobBloc, Stream<JobState>.value(jobState));

      final metricsState = DashboardMetricsState(
        metrics: const [
          DashboardMetricData(label: 'Available', value: '10', icon: Icons.explore_outlined),
          DashboardMetricData(label: 'Accepted', value: '2', icon: Icons.handshake_outlined),
          DashboardMetricData(label: 'Earnings', value: 'RM900', icon: Icons.attach_money),
        ],
        loading: false,
        role: UserRoles.freelancer,
        updatedAt: DateTime.now(),
      );
      when(() => metricsCubit.state).thenReturn(metricsState);
      whenListen(metricsCubit, Stream<DashboardMetricsState>.value(metricsState));

      final telemetryDir = Directory.systemTemp.createTempSync('telemetry_test_feed');
      addTearDown(() => telemetryDir.deleteSync(recursive: true));
      final telemetry = TelemetryService(directory: telemetryDir);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<JobBloc>.value(value: jobBloc),
              BlocProvider<DashboardMetricsCubit>.value(value: metricsCubit),
            ],
            child: DashboardHomeTab(
              authState: AuthAuthenticated(
                baseUser.copyWith(role: UserRoles.freelancer, id: 'freelancer-1'),
              ),
              role: UserRoles.freelancer,
              telemetryService: telemetry,
              listType: JobListType.available,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Design landing page'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.textContaining('RM'), findsOneWidget);
    });
  });
}
