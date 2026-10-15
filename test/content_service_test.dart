import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxlab/data/remote/services/content_service.dart';

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

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
}
