import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_interceptor.dart';

/// Sends uncaught errors to the backend (`POST /logs`) so production
/// crashes are visible in the server logs. Best effort: never throws, never
/// signs the user out, and sends each distinct error once per session.
class ErrorReporter {
  ErrorReporter(this._dio);

  final Dio _dio;
  final _sent = <String>{};

  static const _maxPerSession = 20;

  Future<void> report(Object error, StackTrace? stack) async {
    final message = error.toString();
    if (_sent.length >= _maxPerSession || !_sent.add(message)) return;
    try {
      await _dio.post(
        '/logs',
        data: {
          'logs': [
            {
              'level': 'error',
              'message': message,
              'source': kIsWeb
                  ? 'app-web'
                  : 'app-${defaultTargetPlatform.name}',
              'stack': stack?.toString() ?? '',
            },
          ],
        },
        options: Options(extra: {AuthInterceptor.skipLogoutOn401: true}),
      );
    } catch (_) {
      // Offline or signed out (the endpoint needs a token): nothing to do.
    }
  }
}

final errorReporterProvider = Provider<ErrorReporter>((ref) {
  return ErrorReporter(ref.read(apiClientProvider));
});
