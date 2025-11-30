import 'package:dio/dio.dart';

/// Custom exceptions for network operations
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  NetworkException(this.message, {this.statusCode, this.data});

  @override
  String toString() =>
      'NetworkException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Exception for connection timeouts
class ConnectionTimeoutException extends NetworkException {
  ConnectionTimeoutException([super.message = 'Connection timeout']);
}

/// Exception for receive timeouts
class ReceiveTimeoutException extends NetworkException {
  ReceiveTimeoutException([super.message = 'Response timeout']);
}

/// Exception for send timeouts
class SendTimeoutException extends NetworkException {
  SendTimeoutException([super.message = 'Request send timeout']);
}

/// Exception for no internet connection
class NoInternetException extends NetworkException {
  NoInternetException([super.message = 'No internet connection']);
}

/// Exception for server errors (5xx)
class ServerException extends NetworkException {
  ServerException(
    super.message, {
    super.statusCode,
    super.data,
  });
}

/// Exception for client errors (4xx)
class ClientException extends NetworkException {
  ClientException(
    super.message, {
    super.statusCode,
    super.data,
  });
}

/// Exception for parse/serialization errors
class ParseException extends NetworkException {
  ParseException([super.message = 'Failed to parse response']);
}

/// Exception for cancelled requests
class CancelledException extends NetworkException {
  CancelledException([super.message = 'Request cancelled']);
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
      return NetworkException('SSL certificate error');
    case DioExceptionType.unknown:
      return NetworkException(error.message ?? 'Unknown network error');
  }
}

