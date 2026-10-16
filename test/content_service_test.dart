import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxlab/data/remote/services/content_service.dart';
import 'package:voxlab/dev/demo_data.dart';

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final Object body;
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _exercise(String id, String type) => {
  'exercise': {'id': id, 'type': type, 'name': id, 'content': {}},
};

void main() {
  test('exercise types the app cannot play are left out of the path', () async {
    final dio = Dio()
      ..httpClientAdapter = _JsonAdapter({
        'data': [
          {
            'id': 1,
            'title': 'T',
            'modules': [
              {
                'id': 1,
                'lessons': [
                  {
                    'lesson': {
                      'id': 1,
                      'exercises': [
                        _exercise('r', 'reading'),
                        _exercise('a', 'audio'),
                        _exercise('o', 'oratory_minigame'),
                        _exercise('v', 'video'),
                      ],
                    },
                  },
                ],
              },
            ],
          },
        ],
      });

    final tracks = await ContentService(dio).getTracks();
    final ids = tracks.single.modules.single.lessons.single.exercises.map(
      (e) => e.id,
    );
    expect(ids, ['r', 'o']);
  });

  test('offline, the last content and its exercises still load', () async {
    final adapter = _JsonAdapter({
      'data': [
        {
          'id': 1,
          'title': 'T',
          'modules': [
            {
              'id': 1,
              'lessons': [
                {
                  'lesson': {
                    'id': 1,
                    'exercises': [_exercise('r', 'reading')],
                  },
                },
              ],
            },
          ],
        },
      ],
    });
    final service = ContentService(
      Dio()..httpClientAdapter = adapter,
      DemoSecureStorage(signedIn: false),
    );
    await service.getTracks();

    adapter.offline = true;
    final tracks = await service.getTracks();
    expect(tracks.single.title, 'T');
    expect((await service.getExercise('r')).type, 'reading');
    await expectLater(
      service.getExercise('nope'),
      throwsA(isA<DioException>()),
    );
  });

  test('offline with nothing cached still reports the error', () async {
    final adapter = _JsonAdapter(const {})..offline = true;
    final service = ContentService(
      Dio()..httpClientAdapter = adapter,
      DemoSecureStorage(signedIn: false),
    );
    await expectLater(service.getTracks(), throwsA(isA<DioException>()));
  });
}
