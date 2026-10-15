import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxlab/core/storage/secure_storage.dart';
import 'package:voxlab/data/local/local_progress_store.dart';
import 'package:voxlab/data/remote/services/progress_sync_service.dart';
import 'package:voxlab/data/repositories/content_repository_impl.dart';
import 'package:voxlab/dev/demo_data.dart';
import 'package:voxlab/domain/models/lesson_status.dart';
import 'package:voxlab/domain/models/progress.dart';
import 'package:voxlab/presentation/shared/providers/auth_provider.dart';
import 'package:voxlab/presentation/shared/providers/progress_provider.dart';
import 'package:voxlab/presentation/shared/providers/repository_providers.dart';

class _FakeSync extends ProgressSyncService {
  _FakeSync(this.remote, {this.reject = const {}}) : super(Dio());

  final Set<String> remote;
  final Set<String> reject;
  final uploaded = <String>[];

  @override
  Future<Set<String>> completedIds() async => remote;

  @override
  Future<void> complete(Progress entry) async {
    if (reject.contains(entry.exerciseId)) throw Exception('404');
    uploaded.add(entry.exerciseId);
  }
}

Progress _done(String id, int score) => Progress(
  exerciseId: id,
  status: LessonStatus.completed,
  score: score,
  completedAt: DateTime(2026, 10, 1),
);

void main() {
  Future<(ProviderContainer, _FakeSync)> signedIn({
    required List<Progress> local,
    required Set<String> remote,
    Set<String> reject = const {},
  }) async {
    final store = DemoProgressStore(seeded: false);
    await store.save(demoUser.id, local);
    final sync = _FakeSync(remote, reject: reject);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
        secureStorageProvider.overrideWithValue(
          DemoSecureStorage(signedIn: true),
        ),
        contentRepositoryProvider.overrideWithValue(DemoContentRepository()),
        localProgressStoreProvider.overrideWithValue(store),
        progressSyncServiceProvider.overrideWithValue(sync),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.notifier).checkAuth();
    container.read(progressNotifierProvider);
    // Load, then the background sync.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return (container, sync);
  }

  test('uploads local-only entries and restores server-only ones', () async {
    final (container, sync) = await signedIn(
      local: [_done('d1', 10), _done('d2', 10)],
      remote: {'d2', 'd3'},
    );

    expect(sync.uploaded, ['d1']);
    final ids = container.read(completedExerciseIdsProvider);
    expect(ids, {'d1', 'd2', 'd3'});
    // d3 comes back with the XP its exercise awards (fixture writing: 15).
    final d3 = container
        .read(progressNotifierProvider)
        .firstWhere((p) => p.exerciseId == 'd3');
    expect(d3.score, 15);
    expect(d3.completedAt, isNull);
  });

  test('a rejected upload does not stop the others', () async {
    final (_, sync) = await signedIn(
      local: [_done('gone', 10), _done('d1', 10)],
      remote: const {},
      reject: {'gone'},
    );
    expect(sync.uploaded, ['d1']);
  });

  test('a new completion is uploaded right away', () async {
    final (container, sync) = await signedIn(local: const [], remote: const {});
    await container
        .read(progressNotifierProvider.notifier)
        .saveProgress(
          exerciseId: 'd4',
          status: LessonStatus.completed,
          score: 20,
        );
    await Future<void>.delayed(Duration.zero);
    expect(sync.uploaded, ['d4']);
  });
}
