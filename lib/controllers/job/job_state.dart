import 'package:equatable/equatable.dart';

import '../../models/job.dart';
import '../../models/job_list_type.dart';
import '../../models/review.dart';

class JobFeedState extends Equatable {
  const JobFeedState({
    this.jobs = const [],
    this.page = 0,
    this.pageSize = 20,
    this.hasMore = true,
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.searchQuery = '',
    this.statusFilter,
    this.categoryFilter,
    this.minBudget,
    this.maxBudget,
    this.locationFilter,
    this.initialized = false,
  });

  final List<Job> jobs;
  final int page;
  final int pageSize;
  final bool hasMore;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool isRefreshing;
  final String? errorMessage;
  final String searchQuery;
  final JobStatus? statusFilter;
  final String? categoryFilter;
  final double? minBudget;
  final double? maxBudget;
  final String? locationFilter;
  final bool initialized;

  bool get isEmpty => jobs.isEmpty;

  JobFeedState copyWith({
    List<Job>? jobs,
    int? page,
    int? pageSize,
    bool? hasMore,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? isRefreshing,
    String? errorMessage,
    String? searchQuery,
    JobStatus? statusFilter,
    String? categoryFilter,
    double? minBudget,
    double? maxBudget,
    String? locationFilter,
    bool? initialized,
    bool clearError = false,
    bool clearStatusFilter = false,
    bool clearCategoryFilter = false,
    bool clearBudgetFilter = false,
    bool clearLocationFilter = false,
  }) {
    return JobFeedState(
      jobs: jobs ?? this.jobs,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      minBudget: clearBudgetFilter ? null : (minBudget ?? this.minBudget),
      maxBudget: clearBudgetFilter ? null : (maxBudget ?? this.maxBudget),
      locationFilter: clearLocationFilter
          ? null
          : (locationFilter ?? this.locationFilter),
      initialized: initialized ?? this.initialized,
    );
  }

  bool matchesFilters(Job job) {
    final matchesStatus = statusFilter == null || job.status == statusFilter;
    final matchesCategory =
        categoryFilter == null || categoryFilter!.isEmpty || job.category == categoryFilter;
    final query = searchQuery.trim().toLowerCase();
    final matchesSearch = query.isEmpty ||
        job.title.toLowerCase().contains(query) ||
        job.description.toLowerCase().contains(query) ||
        job.category.toLowerCase().contains(query);
    final matchesBudget = (minBudget == null || job.price >= minBudget!) &&
        (maxBudget == null || job.price <= maxBudget!);
    final matchesLocation = locationFilter == null ||
        locationFilter!.isEmpty ||
        job.location.toLowerCase().contains(locationFilter!.toLowerCase());
    return matchesStatus && matchesCategory && matchesSearch && matchesBudget && matchesLocation;
  }

  @override
  List<Object?> get props => [
        jobs,
        page,
        pageSize,
        hasMore,
        isLoadingInitial,
        isLoadingMore,
        isRefreshing,
        errorMessage,
        searchQuery,
        statusFilter,
        categoryFilter,
        minBudget,
        maxBudget,
        locationFilter,
        initialized,
      ];
}

class JobAlert extends Equatable {
  const JobAlert({
    required this.title,
    required this.message,
    required this.job,
  });

  final String title;
  final String message;
  final Job job;

  @override
  List<Object?> get props => [title, message, job];
}

class JobState extends Equatable {
  const JobState({
    this.feeds = const <JobListType, JobFeedState>{},
    this.selectedJob,
    this.isLoadingDetail = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.currentList = JobListType.available,
    this.notification,
    this.categories = const <String>{},
    this.reviewPromptJob,
    this.submittedReview,
  });

  final Map<JobListType, JobFeedState> feeds;
  final Job? selectedJob;
  final bool isLoadingDetail;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;
  final JobListType currentList;
  final JobAlert? notification;
  final Set<String> categories;
  final Job? reviewPromptJob;
  final Review? submittedReview;

  JobFeedState feedFor(JobListType type) => feeds[type] ?? const JobFeedState();

  JobState copyWith({
    Map<JobListType, JobFeedState>? feeds,
    Job? selectedJob,
    bool? isLoadingDetail,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    JobListType? currentList,
    JobAlert? notification,
    Set<String>? categories,
    Job? reviewPromptJob,
    Review? submittedReview,
    bool clearSelectedJob = false,
    bool clearError = false,
    bool clearMessage = false,
    bool clearNotification = false,
    bool clearReviewPrompt = false,
    bool clearSubmittedReview = false,
  }) {
    return JobState(
      feeds: feeds ?? this.feeds,
      selectedJob:
          clearSelectedJob ? null : (selectedJob ?? this.selectedJob),
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessage ? null : (successMessage ?? this.successMessage),
      currentList: currentList ?? this.currentList,
      notification:
          clearNotification ? null : (notification ?? this.notification),
      categories: categories ?? this.categories,
      reviewPromptJob:
          clearReviewPrompt ? null : (reviewPromptJob ?? this.reviewPromptJob),
      submittedReview: clearSubmittedReview
          ? null
          : (submittedReview ?? this.submittedReview),
    );
  }

  @override
  List<Object?> get props => [
        feeds,
        selectedJob,
        isLoadingDetail,
        isSubmitting,
        errorMessage,
        successMessage,
        currentList,
        notification,
        categories,
        reviewPromptJob,
        submittedReview,
      ];
}
