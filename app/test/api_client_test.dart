import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saathi/core/api/api_client.dart';
import 'package:saathi/core/storage/token_storage.dart';

/// Replays canned bytes in small pieces, like a slow mobile network.
class _ChunkedAdapter implements HttpClientAdapter {
  _ChunkedAdapter(this.body, {this.status = 200, this.chunkSize = 7});

  final String body;
  final int status;
  final int chunkSize;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final bytes = utf8.encode(body);
    final chunks = [
      for (var i = 0; i < bytes.length; i += chunkSize)
        Uint8List.fromList(
          bytes.sublist(i, (i + chunkSize).clamp(0, bytes.length)),
        ),
    ];
    return ResponseBody(
      Stream.fromIterable(chunks),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_ChunkedAdapter adapter) =>
    ApiClient(TokenStorage(), dio: Dio()..httpClientAdapter = adapter);

void main() {
  test(
    'postStream reassembles SSE events split across network chunks',
    () async {
      const body =
          'event: sources\ndata: {"sources": []}\n\n'
          'event: token\ndata: {"text": "प्रकाश "}\n\n'
          'event: token\ndata: {"text": "संश्लेषण"}\n\n'
          'event: done\ndata: {"doubt_id": 7, "from_cache": false}\n\n';

      final events = await _client(_ChunkedAdapter(body, chunkSize: 5))
          .postStream('/x')
          .toList();

      expect(events.map((e) => e.event), ['sources', 'token', 'token', 'done']);
      expect(
        events
            .where((e) => e.event == 'token')
            .map((e) => e.data['text'])
            .join(),
        'प्रकाश संश्लेषण',
      );
      expect(events.last.data['doubt_id'], 7);
    },
  );

  test('FastAPI error detail becomes a readable ApiException', () async {
    final client = _client(
      _ChunkedAdapter('{"detail": "No classroom with that code"}', status: 404),
    );
    await expectLater(
      client.post<Object>('/classrooms/join'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'No classroom with that code')
            .having((e) => e.statusCode, 'status', 404)
            .having((e) => e.isNetwork, 'isNetwork', false),
      ),
    );
  });

  test('validation error list is reduced to its first message', () {
    final e = ApiException.from(
      DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 422,
          data: {
            'detail': [
              {
                'loc': ['body', 'email'],
                'msg': 'value is not a valid email',
              },
            ],
          },
        ),
      ),
    );
    expect(e.message, 'value is not a valid email');
  });

  test('a request that never reaches the server is a network error', () {
    final e = ApiException.from(
      DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: 'offline',
      ),
    );
    expect(e.isNetwork, isTrue);
  });
}
