import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../domain/models/progress.dart';

/// Backs up local progress on the server (`/progress`), so it survives a
/// reinstall and follows the account across Android, iOS and the web. The
/// server also keeps the streak shown in the stats bar.
class ProgressSyncService {
  ProgressSyncService(this._dio);

  final Dio _dio;

  /// Sync is best effort: a 401 here must not sign the user out.
  static final _optional = Options(
    extra: {AuthInterceptor.skipLogoutOn401: true},
  );

  Future<Set<String>> completedIds() async {
    final response = await _dio.get('/progress', options: _optional);
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    return (data['completed_exercise_ids'] as List? ?? [])
        .whereType<String>()
        .toSet();
  }

  /// Idempotent on the server: an exercise already stored is ignored.
  Future<void> complete(Progress entry) async {
    await _dio.post(
      '/progress',
      data: {
        'exercise_id': entry.exerciseId,
        'score': (entry.score ?? 0).clamp(0, 100),
        'completed_at': (entry.completedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
        'lesson_id': ?entry.lessonId,
      },
      options: _optional,
    );
  }
}

final progressSyncServiceProvider = Provider<ProgressSyncService>((ref) {
  return ProgressSyncService(ref.read(apiClientProvider));
});
