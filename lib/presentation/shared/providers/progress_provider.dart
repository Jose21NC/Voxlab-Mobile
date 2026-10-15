import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_progress_store.dart';
import '../../../data/remote/services/progress_sync_service.dart';
import '../../../data/repositories/content_repository_impl.dart';
import '../../../domain/models/lesson_status.dart';
import '../../../domain/models/progress.dart';
import '../../../utils/exercise_name_utils.dart';
import '../../../utils/unlock_utils.dart';
import '../providers/auth_provider.dart';
import 'content_provider.dart';
import 'game_records_provider.dart';

final totalXpStateProvider = Provider<int>((ref) {
  final entries = ref.watch(progressNotifierProvider);
  final lessons = entries.fold(0, (int sum, p) => sum + (p.score ?? 0));
  // Minigames on the Practice tab earn XP too.
  return lessons + ref.watch(gameRecordsProvider).xp;
});

final completedExerciseIdsProvider = Provider<Set<String>>((ref) {
  final entries = ref.watch(progressNotifierProvider);
  return entries.map((p) => p.exerciseId).toSet();
});

final completedExerciseCountProvider = Provider<int>((ref) {
  final completedIds = ref.watch(completedExerciseIdsProvider);
  return completedIds.length;
});

/// Exercises the user may open (see [unlockedExerciseIds]); null while the
/// content is still loading.
final unlockedExerciseIdsProvider = Provider<Set<String>?>((ref) {
  final tracks = ref.watch(tracksProvider).valueOrNull;
  if (tracks == null) return null;
  return unlockedExerciseIds(tracks, ref.watch(completedExerciseIdsProvider));
});

/// Progression scoped to the signed-in user.
///
/// Rebuilds whenever the authenticated user changes and loads that user's
/// entries from [LocalProgressStore], which stays the source of truth: the
/// app works offline. The server is a backup ([ProgressSyncService]): new
/// completions are sent to it, and on load the two sides are merged so
/// progress follows the account to a new device.
class ProgressNotifier extends Notifier<List<Progress>> {
  String? _userId;

  LocalProgressStore get _store => ref.read(localProgressStoreProvider);

  @override
  List<Progress> build() {
    _userId = ref.watch(authProvider.select((s) => s.user?.id));
    if (_userId != null) Future.microtask(reload);
    return const <Progress>[];
  }

  Future<void> reload() async {
    final userId = _userId;
    if (userId == null) {
      state = const <Progress>[];
      return;
    }
    final entries = await _store.load(userId);
    // Ignore a load that finished after the user changed.
    if (_userId != userId) return;
    state = entries;
    unawaited(_syncWithServer(userId));
  }

  /// Uploads what only this device has and restores what only the server
  /// has. Any failure (offline, old backend) leaves local progress as is.
  Future<void> _syncWithServer(String userId) async {
    final sync = ref.read(progressSyncServiceProvider);
    try {
      final remote = await sync.completedIds();
      if (_userId != userId) return;
      final local = state.map((p) => p.exerciseId).toSet();

      final toUpload = state.where((p) => !remote.contains(p.exerciseId));
      for (final entry in toUpload.toList()) {
        try {
          await sync.complete(entry);
        } catch (e) {
          // One rejected entry (e.g. an exercise deleted on the server)
          // must not stop the rest.
          debugPrint('Progress upload of ${entry.exerciseId} skipped: $e');
        }
      }

      final missing = remote.difference(local);
      if (missing.isNotEmpty) {
        // The server stores no score per exercise: restore the XP each one
        // awards. No date either, so they do not inflate today's chart.
        final rewards = <String, int>{};
        try {
          final tracks = await ref.read(contentRepositoryProvider).getTracks();
          for (final lesson
              in tracks.expand((t) => t.modules).expand((m) => m.lessons)) {
            for (final e in lesson.exercises) {
              rewards[e.id] = exerciseXpReward(e);
            }
          }
        } catch (_) {}
        if (_userId != userId) return;
        state = [
          ...state,
          for (final id in missing)
            Progress(
              exerciseId: id,
              status: LessonStatus.completed,
              score: rewards[id],
            ),
        ];
        await _persist();
      }
      if (toUpload.isNotEmpty) {
        await ref.read(authProvider.notifier).refreshUser();
      }
    } catch (e) {
      debugPrint('Progress sync skipped: $e');
    }
  }

  Future<void> saveProgress({
    required String exerciseId,
    int? lessonId,
    required LessonStatus status,
    int? score,
  }) async {
    if (state.any((p) => p.exerciseId == exerciseId)) return;

    final entry = Progress(
      exerciseId: exerciseId,
      lessonId: lessonId,
      status: status,
      score: score,
      completedAt: status == LessonStatus.completed ? DateTime.now() : null,
    );
    state = [...state, entry];
    await _persist();
    unawaited(_upload(entry));
  }

  Future<void> _upload(Progress entry) async {
    try {
      await ref.read(progressSyncServiceProvider).complete(entry);
      // The server updates the streak shown in the stats bar.
      await ref.read(authProvider.notifier).refreshUser();
    } catch (e) {
      // Retried by the next sync on load.
      debugPrint('Progress upload skipped: $e');
    }
  }

  Future<void> _persist() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _store.save(userId, state);
    } catch (e) {
      debugPrint('LocalProgressStore persist error: $e');
    }
  }
}

final progressNotifierProvider =
    NotifierProvider<ProgressNotifier, List<Progress>>(ProgressNotifier.new);
