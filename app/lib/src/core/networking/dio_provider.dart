import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';
import 'network_exceptions.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.add(_RetryInterceptor(dio));
  dio.interceptors.add(_ErrorHandlerInterceptor());

  // Minimal API logging in debug mode
  if (kDebugMode) {
    dio.interceptors.add(_MinimalLogInterceptor());
  }

  return dio;
});

/// Interceptor for automatic request retry on failure
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries = 3;
  final Duration retryDelay = const Duration(milliseconds: 1000);

  _RetryInterceptor(this.dio);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final extra = err.requestOptions.extra;
    final retryCount = extra['retryCount'] ?? 0;

    // Don't retry on client errors (4xx)
    if (err.response?.statusCode != null &&
        err.response!.statusCode! >= 400 &&
        err.response!.statusCode! < 500) {
      return handler.next(err);
    }

    if (retryCount >= maxRetries) {
      Log.w('Max retries exceeded');
      return handler.next(err);
    }

    if (!_shouldRetry(err.type)) {
      return handler.next(err);
    }

    extra['retryCount'] = retryCount + 1;
    Log.network('Retry ${retryCount + 1}/$maxRetries');

    // Wait before retrying
    await Future.delayed(retryDelay);

    try {
      final opts = err.requestOptions;
      final response = await dio.request(
        opts.path,
        data: opts.data,
        queryParameters: opts.queryParameters,
        options: Options(
          method: opts.method,
          headers: opts.headers,
          responseType: opts.responseType,
          contentType: opts.contentType,
          validateStatus: opts.validateStatus,
          receiveDataWhenStatusError: opts.receiveDataWhenStatusError,
          followRedirects: opts.followRedirects,
          maxRedirects: opts.maxRedirects,
          requestEncoder: opts.requestEncoder,
          responseDecoder: opts.responseDecoder,
          listFormat: opts.listFormat,
          extra: extra,
        ),
      );

      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _shouldRetry(DioExceptionType type) {
    return type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.connectionError;
  }
}

/// Interceptor to convert Dio errors to custom exceptions
class _ErrorHandlerInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = handleDioError(err);
    Log.e('Network: ${exception.message}');
    // Reject with custom exception so callers receive the transformed error
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
        message: exception.message,
      ),
    );
  }
}

/// Minimal single-line API logging
class _MinimalLogInterceptor extends Interceptor {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _stopwatch.reset();
    _stopwatch.start();
    Log.api(options.method, options.uri.toString());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _stopwatch.stop();
    final ms = _stopwatch.elapsedMilliseconds;
    Log.api(
      response.requestOptions.method,
      response.requestOptions.uri.toString(),
      status: response.statusCode,
    );
    Log.d('    ↳ ${ms}ms');
    handler.next(response);
  }
}
