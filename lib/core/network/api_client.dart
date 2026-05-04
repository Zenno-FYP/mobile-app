import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/env_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient({void Function()? onForceLogout})
      : _dio = Dio(
          BaseOptions(
            baseUrl: EnvConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
            // Treat any non-2xx as a Dio error so callers see uniform exceptions.
            validateStatus: (status) => status != null && status < 400,
          ),
        ) {
    _dio.interceptors.add(AuthInterceptor(dio: _dio, onForceLogout: onForceLogout));
    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        compact: true,
      ));
    }
  }

  final Dio _dio;
  Dio get dio => _dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParams);
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'data': response.data};
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'data': response.data};
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'data': response.data};
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'data': response.data};
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    String message;

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out. Please check your internet connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection.';
    } else if (e.response?.data is Map) {
      message = (e.response!.data as Map)['message']?.toString() ??
          e.message ??
          'Unknown error';
    } else {
      message = e.message ?? 'Unknown error';
    }

    return ApiException(message: message, statusCode: statusCode);
  }
}
