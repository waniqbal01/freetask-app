import 'package:dio/dio.dart';

import '../models/job.dart';
import '../utils/role_permissions.dart';
import 'api_client.dart';
import 'role_guard.dart';

class JobService {
  JobService(this._apiClient, this._roleGuard);

  final ApiClient _apiClient;
  final RoleGuard _roleGuard;

  Future<List<Job>> fetchJobs({JobStatus? status, bool mine = false}) async {
    try {
      final permission = mine ? RolePermission.viewOwnJobs : RolePermission.viewJobs;
      _roleGuard.ensurePermission(permission);
      final response = await _apiClient.client.get<List<dynamic>>(
        '/jobs',
        queryParameters: {
          if (status != null) 'status': _statusToParam(status),
          if (mine) 'mine': true,
        },
        options: _apiClient.guard(permission: permission),
      );
      final data = response.data ?? const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Job.fromJson)
          .toList();
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
    List<String> attachments = const [],
  }) async {
    try {
      _roleGuard.ensurePermission(RolePermission.createJob);
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/jobs',
        data: {
          'title': title,
          'description': description,
          'price': price,
          'category': category,
          'location': location,
          'attachments': attachments,
        },
        options: _apiClient.guard(permission: RolePermission.createJob),
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
    try {
      _roleGuard.ensurePermission(RolePermission.acceptJob);
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/jobs/$id/accept',
        options: _apiClient.guard(permission: RolePermission.acceptJob),
      );
      final data = response.data ?? <String, dynamic>{};
      return Job.fromJson(data);
    } on DioException catch (error) {
      throw JobException(_mapError(error));
    } on RoleUnauthorizedException catch (error) {
      throw JobException(error.message);
    }
  }

  Future<Job> completeJob(String id) async {
    try {
      _roleGuard.ensurePermission(RolePermission.completeJob);
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/jobs/$id/complete',
        options: _apiClient.guard(permission: RolePermission.completeJob),
      );
      final data = response.data ?? <String, dynamic>{};
      return Job.fromJson(data);
    } on DioException catch (error) {
      throw JobException(_mapError(error));
    } on RoleUnauthorizedException catch (error) {
      throw JobException(error.message);
    }
  }

  Future<Job> payForJob(String id) async {
    try {
      _roleGuard.ensurePermission(RolePermission.payJob);
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/jobs/$id/pay',
        options: _apiClient.guard(permission: RolePermission.payJob),
      );
      final data = response.data ?? <String, dynamic>{};
      return Job.fromJson(data);
    } on DioException catch (error) {
      throw JobException(_mapError(error));
    } on RoleUnauthorizedException catch (error) {
      throw JobException(error.message);
    }
  }

  String _mapError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
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
        case 401:
          return 'Session expired. Please login again.';
        case 404:
          return 'Job not found.';
        default:
          return 'Server error (${response.statusCode}).';
      }
    }
    return 'Something went wrong. Please try again later.';
  }

  String _statusToParam(JobStatus status) {
    switch (status) {
      case JobStatus.pending:
        return 'pending';
      case JobStatus.inProgress:
        return 'in_progress';
      case JobStatus.completed:
        return 'completed';
    }
  }
}

class JobException implements Exception {
  JobException(this.message);

  final String message;

  @override
  String toString() => 'JobException: $message';
}
