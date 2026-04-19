import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Attaches a Firebase ID token to every outbound request and transparently
/// retries a single time on 401 with a force-refreshed token.
///
/// Hardening over a naive implementation:
///   * **Coalesces concurrent 401s** — if many in-flight requests come back
///     401 at roughly the same time (typical right after a token expires),
///     we only call `getIdToken(force: true)` once and let every retry share
///     the result. Otherwise Firebase would be hammered with N parallel
///     refresh calls and we'd risk N parallel logouts on failure.
///   * **Coalesces concurrent token reads** — `onRequest` also funnels
///     through the same single-flight refresh so that an in-progress refresh
///     blocks new requests from racing it with a stale token.
///   * **Force-logout on refresh failure** — surface the failure exactly
///     once via [onForceLogout] so the router can drop the user back at the
///     auth screen instead of looping on stale credentials.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.dio, this.onForceLogout});

  /// The Dio used to retry the failing request after a token refresh.
  /// Must point at the same base URL/headers as the originating client.
  final Dio dio;
  final VoidCallback? onForceLogout;

  static const _retryFlag = 'x-zenno-retry';

  // Single-flight token refresh: while a refresh is in progress, every
  // caller awaits the same Completer instead of starting its own.
  Completer<String?>? _refreshInFlight;

  // Latch so we never invoke onForceLogout repeatedly during a storm of
  // concurrent 401s after a refresh failure.
  bool _logoutTriggered = false;

  Future<String?> _getFreshToken({required bool force}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    if (!force) {
      try {
        return await user.getIdToken();
      } catch (e) {
        developer.log('AuthInterceptor: getIdToken failed', error: e);
        return null;
      }
    }

    // Force refresh path — coalesce parallel callers.
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<String?>();
    _refreshInFlight = completer;
    try {
      final fresh = await user.getIdToken(true);
      completer.complete(fresh);
      return fresh;
    } catch (e, st) {
      developer.log('AuthInterceptor: forced refresh failed', error: e);
      completer.completeError(e, st);
      rethrow;
    } finally {
      _refreshInFlight = null;
    }
  }

  void _triggerLogoutOnce() {
    if (_logoutTriggered) return;
    _logoutTriggered = true;
    onForceLogout?.call();
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // If a refresh is in flight, wait for it so we attach the new token
      // rather than the old one.
      final pending = _refreshInFlight;
      if (pending != null) {
        try {
          final token = await pending.future;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        } catch (_) {
          // Refresh failed elsewhere; fall through and let the request go
          // out without a token — the server will 401 and onError handles it.
        }
      }

      final token = await _getFreshToken(force: false);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        // Reset the logout latch on a successful (non-forced) token attach;
        // the user clearly has a valid session again.
        _logoutTriggered = false;
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
      _triggerLogoutOnce();
      return handler.next(err);
    }

    try {
      final newToken = await _getFreshToken(force: true);
      if (newToken == null) {
        _triggerLogoutOnce();
        return handler.next(err);
      }

      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newToken'
        ..extra[_retryFlag] = true;

      final response = await dio.fetch<dynamic>(retryOptions);
      return handler.resolve(response);
    } catch (e) {
      developer.log('AuthInterceptor: retry failed', error: e);
      _triggerLogoutOnce();
      return handler.next(err);
    }
  }
}
