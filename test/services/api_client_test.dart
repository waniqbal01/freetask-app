import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'package:freetask_app/services/api_client.dart';
import 'package:freetask_app/services/auth_service.dart';
import 'package:freetask_app/services/key_value_store.dart';
import 'package:freetask_app/services/role_guard.dart';
import 'package:freetask_app/services/storage_service.dart';

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(List<ResponseBody> responses)
      : _responses = Queue<ResponseBody>.of(responses);

  final Queue<ResponseBody> _responses;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    if (_responses.isEmpty) {
      throw StateError('No responses configured for request to \'${options.path}\'.');
    }
    return _responses.removeFirst();
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiClient refresh flow', () {
    late StorageService storage;
    late Dio dio;
    late RoleGuard roleGuard;

    setUp(() {
      storage = StorageService(InMemoryKeyValueStore());
      roleGuard = RoleGuard(storage);
      dio = Dio();
    });

    test('retries request after successful refresh', () async {
      await storage.saveToken('expired-token');
      await storage.saveRefreshToken('refresh-token');

      final adapter = _SequenceAdapter(<ResponseBody>[
        ResponseBody.fromString(
          jsonEncode({'message': 'unauthorized'}),
          401,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
        ResponseBody.fromString(
          jsonEncode({'data': 'ok'}),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      ]);
      dio.httpClientAdapter = adapter;

      final api = ApiClient(dio, storage, roleGuard);
      var refreshCalled = false;
      api.setRefreshCallback(() async {
        refreshCalled = true;
        await storage.saveToken('refreshed-token');
        return 'refreshed-token';
      });

      final response = await api.client.get<Map<String, dynamic>>('/protected');

      expect(response.data, containsPair('data', 'ok'));
      expect(refreshCalled, isTrue);
      expect(adapter.requests, hasLength(2));
      expect(storage.token, 'refreshed-token');
    });

    test('clears storage when refresh token flow fails', () async {
      await storage.saveToken('expired-token');
      await storage.saveRefreshToken('refresh-token');

      final adapter = _SequenceAdapter(<ResponseBody>[
        ResponseBody.fromString(
          jsonEncode({'message': 'unauthorized'}),
          401,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      ]);
      dio.httpClientAdapter = adapter;

      final api = ApiClient(dio, storage, roleGuard);
      api.setRefreshCallback(() async {
        throw AuthException('Session expired');
      });

      expect(
        () => api.client.get<Map<String, dynamic>>('/protected'),
        throwsA(isA<DioException>()),
      );
      expect(storage.token, isNull);
      expect(storage.refreshToken, isNull);
    });

    test('emits logout event when refresh token fails once', () async {
      await storage.saveToken('expired-token');
      await storage.saveRefreshToken('refresh-token');

      final adapter = _SequenceAdapter(<ResponseBody>[
        ResponseBody.fromString(
          jsonEncode({'message': 'unauthorized'}),
          401,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      ]);
      dio.httpClientAdapter = adapter;

      final api = ApiClient(dio, storage, roleGuard);
      final logoutEvents = <Object?>[];
      api.logoutStream.listen((_) => logoutEvents.add(null));
      api.setRefreshCallback(() async {
        throw AuthException('Session expired');
      });

      await expectLater(
        () => api.client.get<Map<String, dynamic>>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(storage.token, isNull);
      expect(storage.refreshToken, isNull);
      expect(adapter.requests, hasLength(1));
      await Future.delayed(Duration.zero);
      expect(logoutEvents, isNotEmpty);
    });
  });

  group('RoleGuard.ensureRoleIn', () {
    test('throws when current role not in allowed set', () async {
      final storage = StorageService(InMemoryKeyValueStore());
      final guard = RoleGuard(storage);

      expect(
        () => guard.ensureRoleIn({'admin', 'manager'}),
        throwsA(isA<RoleUnauthorizedException>()),
      );
    });
  });
}
