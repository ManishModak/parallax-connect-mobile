import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';
import '../exceptions/network_exceptions.dart';

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
  dio.interceptors.add(_CancellationInterceptor());

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
  final Duration initialRetryDelay = const Duration(milliseconds: 500);
  final double backoffFactor = 2.0;

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

    // Calculate exponential backoff delay
    final delay = initialRetryDelay * pow(backoffFactor, retryCount);
    final jitter = Duration(
      milliseconds: Random().nextInt(200),
    ); // Add jitter to prevent thundering herd
    final totalDelay = delay + jitter;

    Log.network(
      'Retrying in ${totalDelay.inMilliseconds}ms (exponential backoff)',
    );

    // Wait before retrying
    await Future.delayed(totalDelay);

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

/// Interceptor for request cancellation support
class _CancellationInterceptor extends Interceptor {
  final Map<String, CancelToken> _cancelTokens = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Create a unique key for this request
    final requestKey = '${options.method}_${options.path}';

    // Create or reuse cancel token
    final cancelToken = CancelToken();
    _cancelTokens[requestKey] = cancelToken;

    // Add cancel token to request options
    options.cancelToken = cancelToken;

    Log.network('Request started with cancellation support: $requestKey');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Clean up cancel token when request completes
    final requestKey =
        '${response.requestOptions.method}_${response.requestOptions.path}';
    _cancelTokens.remove(requestKey);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Clean up cancel token when request fails
    final requestKey =
        '${err.requestOptions.method}_${err.requestOptions.path}';
    _cancelTokens.remove(requestKey);
    handler.next(err);
  }

  /// Cancel all pending requests
  void cancelAllRequests() {
    Log.network('Cancelling all pending requests');
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) {
        token.cancel('All requests cancelled');
      }
    }
    _cancelTokens.clear();
  }

  /// Cancel specific request by method and path
  void cancelRequest(String method, String path) {
    final requestKey = '${method}_$path';
    final token = _cancelTokens[requestKey];
    if (token != null && !token.isCancelled) {
      Log.network('Cancelling request: $requestKey');
      token.cancel('Request cancelled');
      _cancelTokens.remove(requestKey);
    }
  }
}

/// Minimal single-line API logging
/// Uses per-request timing stored in extras to avoid race conditions
class _MinimalLogInterceptor extends Interceptor {
  static const _startTimeKey = '_requestStartTime';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startTimeKey] = DateTime.now().millisecondsSinceEpoch;
    Log.api(options.method, options.uri.toString());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = response.requestOptions.extra[_startTimeKey] as int?;
    final ms = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : 0;
    Log.api(
      response.requestOptions.method,
      response.requestOptions.uri.toString(),
      status: response.statusCode,
    );
    Log.d('    ↳ ${ms}ms');
    handler.next(response);
  }
}
