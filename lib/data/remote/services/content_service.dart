import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/models/track.dart';
import '../../../domain/models/module.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/models/exercise.dart';
import '../../../domain/models/exercise_content.dart';

class ContentService {
  ContentService(this._dio);

  /// Exercise types this version can play. The API also has `audio` and
  /// `video`; showing them would block the linear path on an exercise
  /// nobody can complete, so they are left out of the map.
  static const playableTypes = {
    'quiz',
    'reading',
    'writing',
    'oratory_minigame',
  };

  final Dio _dio;

  Future<List<Track>> getTracks() async {
    final response = await _dio.get('/tracks');
    final data = response.data['data'] as List;
    return data.map((e) => _mapTrack(e as Map<String, dynamic>)).toList();
  }

  Future<Exercise> getExercise(String id) async {
    final response = await _dio.get('/exercises/$id');
    final data = response.data['data'] as Map<String, dynamic>;
    return _mapExercise(data);
  }

  Track _mapTrack(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconUrl: json['icon_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      modules:
          (json['modules'] as List?)
              ?.map((e) => _mapModule(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Module _mapModule(Map<String, dynamic> json) {
    return Module(
      id: json['id'] as int? ?? 0,
      trackId: json['track_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      lessons:
          (json['lessons'] as List?)
              ?.map((e) => _mapPivotLesson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Lesson _mapPivotLesson(Map<String, dynamic> json) {
    final lessonJson = json['lesson'] as Map<String, dynamic>? ?? json;
    return _mapLesson(lessonJson);
  }

  Lesson _mapLesson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      estimatedTimeSeconds: json['estimated_time_seconds'] as int?,
      exercises:
          (json['exercises'] as List?)
              ?.map((e) => _mapPivotExercise(e as Map<String, dynamic>))
              .where((e) => playableTypes.contains(e.type))
              .toList() ??
          [],
    );
  }

  Exercise _mapPivotExercise(Map<String, dynamic> json) {
    final exerciseJson = json['exercise'] as Map<String, dynamic>? ?? json;
    return _mapExercise(exerciseJson);
  }

  Exercise _mapExercise(Map<String, dynamic> json) {
    final type = (json['type'] as String?) ?? 'reading';
    final contentJson = json['content'] as Map<String, dynamic>? ?? {};
    return Exercise(
      id: json['id'] as String? ?? '',
      type: type,
      name: json['name'] as String? ?? '',
      content: ExerciseContent.fromJson(contentJson, type),
    );
  }
}

final contentServiceProvider = Provider<ContentService>((ref) {
  return ContentService(ref.read(apiClientProvider));
});
