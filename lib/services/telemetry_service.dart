import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/logger.dart';

/// TelemetryService provides lightweight logging to `/telemetry` so that
/// product analytics can be replayed during QA without depending on external
/// tooling. Each call to [record] appends a JSON line that includes a
/// timestamp and arbitrary payload. The service batches writes to avoid
/// blocking the UI thread when several events are logged at once.
class TelemetryService {
  TelemetryService({
    Directory? directory,
    IOSink? debugSink,
  })  : _directory = directory ?? Directory('/telemetry'),
        _debugSink = debugSink;

  final Directory _directory;
  final IOSink? _debugSink;
  IOSink? _sink;
  Completer<void>? _openCompleter;

  /// Records an interaction. The [event] should describe the interaction while
  /// [properties] capture additional metadata. The operation is fire-and-forget
  /// but awaiting the returned [Future] ensures that disk writes are completed
  /// before continuing.
  Future<void> record(String event, {Map<String, dynamic>? properties}) async {
    try {
      await _ensureSink();
      final payload = <String, dynamic>{
        'event': event,
        'timestamp': DateTime.now().toIso8601String(),
        if (properties != null) ...properties,
      };
      final line = jsonEncode(payload);
      _sink?.writeln(line);
      _debugSink?.writeln(line);
    } catch (error, stackTrace) {
      appLog('Telemetry write failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  Future<void> _ensureSink() async {
    if (_sink != null) return;
    if (_openCompleter != null) {
      return _openCompleter!.future;
    }

    _openCompleter = Completer<void>();
    try {
      if (!_directory.existsSync()) {
        await _directory.create(recursive: true);
      }
      final file = File('${_directory.path}/events.log');
      _sink = file.openWrite(mode: FileMode.append);
      _openCompleter!.complete();
    } catch (error, stackTrace) {
      appLog('Unable to open telemetry sink', error: error, stackTrace: stackTrace);
      _openCompleter!.completeError(error, stackTrace);
      rethrow;
    } finally {
      _openCompleter = null;
    }
  }
}
