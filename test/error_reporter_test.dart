import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxlab/core/network/error_reporter.dart';

class _Recorder implements HttpClientAdapter {
  final bodies = <Map<String, dynamic>>[];
  int status = 202;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bodies.add(options.data as Map<String, dynamic>);
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('sends each distinct error once and never throws', () async {
    final adapter = _Recorder();
    final reporter = ErrorReporter(Dio()..httpClientAdapter = adapter);

    await reporter.report(StateError('boom'), StackTrace.current);
    await reporter.report(StateError('boom'), StackTrace.current);
    adapter.status = 500;
    await reporter.report(StateError('other'), null);

    expect(adapter.bodies, hasLength(2));
    final log = (adapter.bodies.first['logs'] as List).single as Map;
    expect(log['level'], 'error');
    expect(log['message'], contains('boom'));
    expect(jsonEncode(adapter.bodies.last), contains('other'));
  });
}
