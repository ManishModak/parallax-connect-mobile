import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

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

  // Add retry interceptor
  dio.interceptors.add(_RetryInterceptor(dio));

  // Add error handling interceptor
  dio.interceptors.add(_ErrorHandlerInterceptor());

  // Add logger only in debug mode
  if (kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: false, // Reduced verbosity
        responseBody: true,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );
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

    // Don't retry on client errors (4xx) or if max retries exceeded
    if (err.response?.statusCode != null &&
        err.response!.statusCode! >= 400 &&
        err.response!.statusCode! < 500) {
      logger.w('Client error, not retrying: ${err.response?.statusCode}');
      return handler.next(err);
    }

    if (retryCount >= maxRetries) {
      logger.e('Max retries ($maxRetries) exceeded');
      return handler.next(err);
    }

    // Check if error is retryable
    if (!_shouldRetry(err.type)) {
      logger.w('Error type not retryable: ${err.type}');
      return handler.next(err);
    }

    // Increment retry count
    extra['retryCount'] = retryCount + 1;

    logger.network(
      'Retrying request (${retryCount + 1}/$maxRetries) after ${retryDelay.inMilliseconds}ms',
    );

    // Wait before retrying
    await Future.delayed(retryDelay);

    try {
      final response = await dio.request(
        err.requestOptions.path,
        data: err.requestOptions.data,
        queryParameters: err.requestOptions.queryParameters,
        options: Options(
          method: err.requestOptions.method,
          headers: err.requestOptions.headers,
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
    logger.e('Network error: ${exception.message}');
    handler.next(
      err,
    ); // Pass original error, caller can use handleDioError if needed
  }
}
