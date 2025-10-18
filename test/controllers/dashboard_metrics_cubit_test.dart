import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:freetask_app/controllers/dashboard/dashboard_metrics_cubit.dart';
import 'package:freetask_app/controllers/job/job_bloc.dart';
import 'package:freetask_app/controllers/job/job_event.dart';
import 'package:freetask_app/controllers/job/job_state.dart';
import 'package:freetask_app/models/job.dart';
import 'package:freetask_app/models/job_list_type.dart';
import 'package:freetask_app/models/user.dart';
import 'package:freetask_app/services/storage_service.dart';
import 'package:freetask_app/utils/role_permissions.dart';

class _MockJobBloc extends MockBloc<JobEvent, JobState> implements JobBloc {}

class _FakeJobState extends Fake implements JobState {}

class _MockStorageService extends Mock implements StorageService {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeJobState());
    registerFallbackValue(const JobListRequested(JobListType.mine));
  });

  group('DashboardMetricsCubit', () {
    late _MockJobBloc jobBloc;
    late _MockStorageService storage;

    setUp(() {
      jobBloc = _MockJobBloc();
      storage = _MockStorageService();
      when(() => jobBloc.stream).thenAnswer((_) => Stream<JobState>.empty());
    });

    DashboardMetricsCubit buildCubit(JobState state, {String? role, User? user}) {
      when(() => jobBloc.state).thenReturn(state);
      when(() => storage.role).thenReturn(role);
      when(() => storage.getUser()).thenReturn(user);
      return DashboardMetricsCubit(jobBloc, storage);
    }

    test('emits loading state immediately', () {
      when(() => jobBloc.state).thenReturn(const JobState());
      final cubit = DashboardMetricsCubit(jobBloc, storage);
      expect(cubit.state.loading, isTrue);
    });

    blocTest<DashboardMetricsCubit, DashboardMetricsState>(
      'computes admin metrics including totals',
      build: () {
        final state = JobState(
          feeds: {
            JobListType.all: JobFeedState(
              jobs: [
                Job(
                  id: '1',
                  title: 'A',
                  description: 'A',
                  price: 100,
                  category: 'Design',
                  location: 'Remote',
                  status: JobStatus.completed,
                  clientId: 'client1',
                  clientName: 'Client',
                  createdAt: DateTime(2024, 1, 1),
                  freelancerId: 'freelancer1',
                  freelancerName: 'Freelancer',
                ),
              ],
              initialized: true,
            ),
          },
        );
        return buildCubit(state, role: UserRoles.admin);
      },
      act: (cubit) => cubit.updateRole(UserRoles.admin),
      expect: () => [
        isA<DashboardMetricsState>().having(
          (state) => state.metrics.map((metric) => metric.label).toList(),
          'labels',
          containsAll(['Users', 'Jobs', 'Revenue', 'Active Freelancers']),
        ),
      ],
    );

    blocTest<DashboardMetricsCubit, DashboardMetricsState>(
      'computes freelancer metrics based on feeds',
      build: () {
        final job = Job(
          id: 'job-1',
          title: 'Design landing page',
          description: 'Create a responsive landing page',
          price: 750,
          category: 'Design',
          location: 'Remote',
          status: JobStatus.completed,
          clientId: 'client-1',
          clientName: 'Marie',
          freelancerId: 'freelancer-1',
          freelancerName: 'Alex',
          createdAt: DateTime.now(),
        );
        final state = JobState(
          feeds: {
            JobListType.available: const JobFeedState(jobs: [], initialized: true),
            JobListType.mine: JobFeedState(jobs: [job], initialized: true),
            JobListType.completed: JobFeedState(jobs: [job], initialized: true),
          },
        );
        return buildCubit(
          state,
          role: UserRoles.freelancer,
          user: const User(
            id: 'freelancer-1',
            name: 'Alex',
            email: 'alex@example.com',
            role: UserRoles.freelancer,
            avatarUrl: null,
            bio: null,
            location: 'Remote',
            phoneNumber: null,
            verified: true,
          ),
        );
      },
      act: (cubit) => cubit.updateRole(UserRoles.freelancer),
      expect: () => [
        isA<DashboardMetricsState>().having(
          (state) => state.metrics.map((metric) => metric.label).toList(),
          'labels',
          containsAll(['Available', 'Accepted', 'Earnings']),
        ),
      ],
    );
  });
}
