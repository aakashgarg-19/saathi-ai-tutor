import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../storage/token_storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isNetwork = false});

  final String message;
  final int? statusCode;

  /// True when the request never reached the server (offline, DNS, timeout).
  final bool isNetwork;

  @override
  String toString() => message;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final response = error.response;
      if (response == null) {
        return ApiException('Could not reach the server', isNetwork: true);
      }
      return ApiException(
        _detail(response.data) ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return ApiException(error.toString());
  }

  static String? _detail(Object? data) {
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail;
      // FastAPI validation errors: [{loc, msg, ...}]
      if (detail is List && detail.isNotEmpty && detail.first is Map) {
        return (detail.first as Map)['msg']?.toString();
      }
    }
    return null;
  }
}

/// One Server-Sent Event.
typedef SseEvent = ({String event, Map<String, dynamic> data});

class ApiClient {
  ApiClient(this._tokens, {void Function()? onUnauthorized, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 60),
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokens.token;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401 && _tokens.token != null) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokens;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => _dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? body}) =>
      _wrap(() => _dio.post<T>(path, data: body));

  Future<T> _wrap<T>(Future<Response<T>> Function() call) async {
    try {
      return (await call()).data as T;
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// POST that returns a `text/event-stream`. Events are yielded as they arrive.
  Stream<SseEvent> postStream(String path, {Object? body}) async* {
    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
    } catch (e) {
      throw ApiException.from(e);
    }

    var event = 'message';
    final data = StringBuffer();
    final lines = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    try {
      await for (final line in lines) {
        if (line.isEmpty) {
          if (data.isNotEmpty) {
            yield (
              event: event,
              data: jsonDecode(data.toString()) as Map<String, dynamic>,
            );
          }
          event = 'message';
          data.clear();
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.write(line.substring(5).trimLeft());
        }
      }
    } catch (e) {
      throw ApiException('Connection lost while answering', isNetwork: true);
    }
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// The auth layer registers a handler here so a 401 anywhere signs the user out.
class UnauthorizedHook {
  void Function()? handler;
}

final unauthorizedHookProvider = Provider<UnauthorizedHook>(
  (ref) => UnauthorizedHook(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(tokenStorageProvider),
    onUnauthorized: () => ref.read(unauthorizedHookProvider).handler?.call(),
  );
});
