import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/job.dart';
import '../models/review.dart';
import '../utils/role_permissions.dart';
import 'api_client.dart';
import 'role_guard.dart';
import 'storage_service.dart';

class JobPaginationResult {
  const JobPaginationResult({
    required this.jobs,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<Job> jobs;
  final int page;
  final int pageSize;
  final int total;

  bool get hasNextPage => jobs.length + (page - 1) * pageSize < total;
}

class JobService {
  JobService(this._apiClient, this._roleGuard, this._storage);

  final ApiClient _apiClient;
  final RoleGuard _roleGuard;
  final StorageService _storage;

  Duration cacheTtl = const Duration(minutes: 5);

  Future<JobPaginationResult> fetchJobs({
    int page = 1,
    int pageSize = 20,
    JobStatus? status,
    String? category,
    String? search,
    bool mine = false,
    bool includeHistory = false,
    double? minBudget,
    double? maxBudget,
    String? location,
    bool useCache = true,
  }) async {
    try {
      final permission = mine
          ? RolePermission.viewOwnJobs
          : RolePermission.viewJobs;
      _roleGuard.ensurePermission(permission);

      final cacheKey = _composeCacheKey(
        page: page,
        pageSize: pageSize,
        status: status,
        category: category,
        search: search,
        mine: mine,
        includeHistory: includeHistory,
        minBudget: minBudget,
        maxBudget: maxBudget,
        location: location,
      );

      if (page == 1 && useCache) {
        final cache = _storage.getCachedJobFeed(cacheKey);
        if (cache != null && cache.isFresh(cacheTtl)) {
          final jobs = cache.jobs.map(Job.fromJson).toList(growable: false);
          return JobPaginationResult(
            jobs: jobs,
            page: cache.page,
            pageSize: cache.pageSize,
            total: cache.total,
          );
        }
      }
      final response = await _apiClient.client.get<dynamic>(
        '/jobs',
        queryParameters: {
          'page': page,
          'limit': pageSize,
          if (status != null) 'status': status.apiValue,
          if (category != null && category.isNotEmpty) 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
          if (mine) 'mine': true,
          if (includeHistory) 'history': true,
          if (minBudget != null) 'minBudget': minBudget,
          if (maxBudget != null) 'maxBudget': maxBudget,
          if (location != null && location.isNotEmpty) 'location': location,
        },
        options: _apiClient.guard(permission: permission),
      );

      final result = _parsePaginationResult(
        response.data,
        fallbackPage: page,
        fallbackPageSize: pageSize,
      );

      if (page == 1) {
        await _storage.cacheJobFeed(
          cacheKey,
          result.jobs.map((job) => job.toJson()).toList(growable: false),
          DateTime.now(),
          page: result.page,
          pageSize: result.pageSize,
          total: result.total,
        );
      }

      return result;
    } on DioException catch (error) {
      throw JobException(_mapError(error));
    } on RoleUnauthorizedException catch (error) {
      throw JobException(error.message);
    }
  }

  Future<Job> fetchJobDetail(String id) async {
    try {
      _roleGuard.ensurePermission(RolePermission.viewJobs);
      final response = await _apiClient.client.get<Map<String, dynamic>>(
        '/jobs/$id',
        options: _apiClient.guard(permission: RolePermission.viewJobs),
      );
      final data = response.data ?? <String, dynamic>{};
      return Job.fromJson(data);
    } on DioException catch (error) {
      throw JobException(_mapError(error));
    } on RoleUnauthorizedException catch (error) {
      throw JobException(error.message);
    }
  }

  Future<Job> createJob({
    required String title,
    required String description,
    required double price,
    required String category,
    required String location,
    List<String> imagePaths = const [],
  }) async {
    try {
      _roleGuard.ensurePermission(RolePermission.createJob);
      final attachments = await _prepareAttachments(imagePaths);
      final payload = FormData.fromMap({
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'location': location,
        if (attachments.isNotEmpty) 'attachments': attachments,
      });

      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/jobs',
        data: payload,
        options: _apiClient.guard(permission: RolePermission.createJob)
            .copyWith(contentType: 'multipart/form-data'),
      );
      final data = response.data ?? <String, dynamic>{};
      return Job.fromJson(data);
    } on DioException catch (error) {
      throw JobException(_mapError(error));
    } on RoleUnauthorizedException catch (error) {
      throw JobException(error.message);
    }
  }

  Future<Job> acceptJob(String id) async {
    return _transition(
      id: id,
      endpoint: '/jobs/$id/accept',
      permission: RolePermission.acceptJob,
    );
  }

  Future<Job> completeJob(String id) async {
    return _transition(
      id: id,
      endpoint: '/jobs/$id/complete',
      permission: RolePermission.completeJob,
    );
  }

  Future<Job> cancelJob(String id) async {
    return _transition(
      id: id,
      endpoint: '/jobs/$id/cancel',
      permission: RolePermission.cancelJob,
    );
  }

  Future<Job> payForJob(String id) async {
    return _transition(
      id: id,
      endpoint: '/jobs/$id/pay',
      permission: RolePermission.payJob,
    );
  }

  Future<Review> submitReview({
    required String jobId,
    required double rating,
    String? comment,
  }) async {
    try {
      _roleGuard.ensurePermission(RolePermission.completeJob);
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/jobs/$jobId/reviews',
        data: {
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
        options: _apiClient.guard(permission: RolePermission.completeJob),
      );
      final data = response.data ?? <String, dynamic>{};
      return Review.fromJson(data);
    } on DioException catch (error) {
      throw JobException(_mapError(error));
    } on RoleUnauthorizedException catch (error) {
      throw JobException(error.message);
    }
  }

  Future<Job> _transition({
    required String id,
    required String endpoint,
    required RolePermission permission,
  }) async {
    try {
      _roleGuard.ensurePermission(permission);
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        endpoint,
        options: _apiClient.guard(permission: permission),
      );
      final data = response.data ?? <String, dynamic>{};
      return Job.fromJson(data);
    } on DioException catch (error) {
      throw JobException(_mapError(error));
    } on RoleUnauthorizedException catch (error) {
      throw JobException(error.message);
    }
  }

  Future<List<MultipartFile>> _prepareAttachments(List<String> imagePaths) async {
    final uploads = <MultipartFile>[];
    for (final path in imagePaths) {
      if (path.isEmpty) continue;
      try {
        uploads.add(
          await MultipartFile.fromFile(
            path,
            filename: path.split('/').last,
          ),
        );
      } catch (_) {
        // Ignore corrupt attachment silently
      }
    }
    return uploads;
  }

  JobPaginationResult _parsePaginationResult(
    dynamic payload, {
    required int fallbackPage,
    required int fallbackPageSize,
  }) {
    if (payload is Map<String, dynamic>) {
      final items = _extractItems(payload);
      final meta = payload['meta'] ?? payload['pagination'] ?? payload['page'];
      final total = _extractTotal(payload, items.length);
      final page = _extractMetaField(meta, 'page') ?? fallbackPage;
      final limit = _extractMetaField(meta, 'limit') ??
          _extractMetaField(meta, 'pageSize') ??
          fallbackPageSize;
      return JobPaginationResult(
        jobs: items,
        page: page,
        pageSize: limit,
        total: total,
      );
    }
    if (payload is List) {
      final jobs = payload
          .whereType<Map<String, dynamic>>()
          .map(Job.fromJson)
          .toList(growable: false);
      return JobPaginationResult(
        jobs: jobs,
        page: fallbackPage,
        pageSize: fallbackPageSize,
        total: jobs.length + (fallbackPage - 1) * fallbackPageSize,
      );
    }
    return JobPaginationResult(
      jobs: const [],
      page: fallbackPage,
      pageSize: fallbackPageSize,
      total: 0,
    );
  }

  List<Job> _extractItems(Map<String, dynamic> payload) {
    final candidates = [
      payload['data'],
      payload['jobs'],
      payload['items'],
      payload['results'],
      payload['rows'],
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map<String, dynamic>>()
            .map(Job.fromJson)
            .toList(growable: false);
      }
    }
    return const [];
  }

  int _extractTotal(Map<String, dynamic> payload, int defaultTotal) {
    final meta = payload['meta'] ?? payload['pagination'] ?? payload['page'];
    final total = _extractMetaField(meta, 'total') ??
        _extractMetaField(meta, 'count') ??
        payload['total'] as int?;
    return total ?? defaultTotal;
  }

  int? _extractMetaField(dynamic meta, String key) {
    if (meta is Map<String, dynamic>) {
      final value = meta[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }
    return null;
  }

  String _mapError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      return 'Connection timed out. Please try again.';
    }
    final response = error.response;
    if (response != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['message'] is String) {
          return data['message'] as String;
        }
        if (data['error'] is String) {
          return data['error'] as String;
        }
      }
      switch (response.statusCode) {
        case 400:
          return 'Invalid job data. Please review your input.';
        case 401:
          return 'Session expired. Please login again.';
        case 403:
          return 'You do not have permission to perform this action.';
        case 404:
          return 'Job not found.';
        default:
          return 'Server error (${response.statusCode}).';
      }
    }
    return 'Something went wrong. Please try again later.';
  }

  String _composeCacheKey({
    required int page,
    required int pageSize,
    JobStatus? status,
    String? category,
    String? search,
    required bool mine,
    required bool includeHistory,
    double? minBudget,
    double? maxBudget,
    String? location,
  }) {
    final buffer = StringBuffer('page=$page|size=$pageSize');
    if (status != null) buffer.write('|status=${status.apiValue}');
    if (category != null && category.isNotEmpty) {
      buffer.write('|cat=${category.toLowerCase()}');
    }
    if (search != null && search.isNotEmpty) {
      buffer.write('|search=${search.toLowerCase()}');
    }
    if (location != null && location.isNotEmpty) {
      buffer.write('|loc=${location.toLowerCase()}');
    }
    if (minBudget != null) buffer.write('|min=$minBudget');
    if (maxBudget != null) buffer.write('|max=$maxBudget');
    buffer
      ..write('|mine=$mine')
      ..write('|history=$includeHistory');
    return buffer.toString();
  }
}

class JobException implements Exception {
  JobException(this.message);

  final String message;

  @override
  String toString() => 'JobException: $message';
}
