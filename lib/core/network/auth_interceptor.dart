import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Attaches a Firebase ID token to every outbound request and transparently
/// retries a single time on 401 with a force-refreshed token. If refresh fails,
/// invokes [onForceLogout] so the app can navigate the user back to /auth.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.dio, this.onForceLogout});

  /// The Dio used to retry the failing request after a token refresh.
  /// Must point at the same base URL/headers as the originating client so the
  /// retry uses the right interceptors-free path.
  final Dio dio;
  final VoidCallback? onForceLogout;

  static const _retryFlag = 'x-zenno-retry';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      developer.log('AuthInterceptor: failed to attach token', error: e);
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retryFlag] == true;

    if (!isUnauthorized || alreadyRetried) {
      return handler.next(err);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onForceLogout?.call();
      return handler.next(err);
    }

    try {
      final newToken = await user.getIdToken(true);
      if (newToken == null) {
        onForceLogout?.call();
        return handler.next(err);
      }

      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newToken'
        ..extra[_retryFlag] = true;

      final response = await dio.fetch<dynamic>(retryOptions);
      return handler.resolve(response);
    } catch (e) {
      developer.log('AuthInterceptor: retry failed', error: e);
      onForceLogout?.call();
      return handler.next(err);
    }
  }
}
