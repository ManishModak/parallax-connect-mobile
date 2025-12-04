import 'package:dio/dio.dart';

/// Custom exceptions for network operations
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  final String? errorCode;

  NetworkException(this.message, {this.statusCode, this.data, this.errorCode});

  @override
  String toString() =>
      'NetworkException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}${errorCode != null ? ' [Code: $errorCode]' : ''}';
}

/// Exception for connection timeouts
class ConnectionTimeoutException extends NetworkException {
  ConnectionTimeoutException([String message = 'Connection timeout'])
    : super(message, errorCode: 'NETWORK_TIMEOUT');
}

/// Exception for receive timeouts
class ReceiveTimeoutException extends NetworkException {
  ReceiveTimeoutException([String message = 'Response timeout'])
    : super(message, errorCode: 'RESPONSE_TIMEOUT');
}

/// Exception for send timeouts
class SendTimeoutException extends NetworkException {
  SendTimeoutException([String message = 'Request send timeout'])
    : super(message, errorCode: 'SEND_TIMEOUT');
}

/// Exception for no internet connection
class NoInternetException extends NetworkException {
  NoInternetException([String message = 'No internet connection'])
    : super(message, errorCode: 'NO_INTERNET');
}

/// Exception for server errors (5xx)
class ServerException extends NetworkException {
  ServerException(
    String message, {
    int? statusCode,
    dynamic data,
    String errorCode = 'SERVER_ERROR',
  }) : super(message, statusCode: statusCode, data: data, errorCode: errorCode);
}

/// Exception for client errors (4xx)
class ClientException extends NetworkException {
  ClientException(
    String message, {
    int? statusCode,
    dynamic data,
    String errorCode = 'CLIENT_ERROR',
  }) : super(message, statusCode: statusCode, data: data, errorCode: errorCode);
}

/// Exception for parse/serialization errors
class ParseException extends NetworkException {
  ParseException([String message = 'Failed to parse response'])
    : super(message, errorCode: 'PARSE_ERROR');
}

/// Exception for cancelled requests
class CancelledException extends NetworkException {
  CancelledException([String message = 'Request cancelled'])
    : super(message, errorCode: 'REQUEST_CANCELLED');
}

/// Helper to convert Dio errors to custom exceptions
NetworkException handleDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
      return ConnectionTimeoutException();
    case DioExceptionType.sendTimeout:
      return SendTimeoutException();
    case DioExceptionType.receiveTimeout:
      return ReceiveTimeoutException();
    case DioExceptionType.badResponse:
      final statusCode = error.response?.statusCode;
      final message = error.response?.statusMessage ?? 'Unknown error';
      if (statusCode != null) {
        if (statusCode >= 500) {
          return ServerException(
            message,
            statusCode: statusCode,
            data: error.response?.data,
          );
        } else if (statusCode >= 400) {
          return ClientException(
            message,
            statusCode: statusCode,
            data: error.response?.data,
          );
        }
      }
      return NetworkException(
        message,
        statusCode: statusCode,
        data: error.response?.data,
      );
    case DioExceptionType.cancel:
      return CancelledException();
    case DioExceptionType.connectionError:
      return NoInternetException();
    case DioExceptionType.badCertificate:
      return NetworkException('SSL certificate error', errorCode: 'SSL_ERROR');
    case DioExceptionType.unknown:
      return NetworkException(
        error.message ?? 'Unknown network error',
        errorCode: 'UNKNOWN_ERROR',
      );
  }
}
