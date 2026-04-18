import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralised access to runtime configuration.
///
/// Resolution order for every key:
///   1. `--dart-define=KEY=...` (compile-time, highest precedence so CI builds
///      can override without a `.env` shipped to the device).
///   2. Value loaded from `.env` at app startup via [EnvConfig.load].
///   3. Hard-coded fallback suitable for local development.
abstract final class EnvConfig {
  static const _kApiBaseUrl = 'API_BASE_URL';
  static const _kEnv = 'ENV';

  static const _defineApiBaseUrl =
      String.fromEnvironment(_kApiBaseUrl, defaultValue: '');
  static const _defineEnv = String.fromEnvironment(_kEnv, defaultValue: '');

  /// Loads `.env` from the bundled assets. Safe to call before `runApp`.
  /// If the file is missing (e.g. on CI builds that rely solely on
  /// `--dart-define`), we silently continue.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env is optional; --dart-define and defaults will fill the gaps.
    }
  }

  static String _read(String key, {required String fallback, String dartDefine = ''}) {
    if (dartDefine.isNotEmpty) return dartDefine;
    final fromDotenv = dotenv.maybeGet(key);
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    return fallback;
  }

  static String get _rawBaseUrl => _read(
        _kApiBaseUrl,
        dartDefine: _defineApiBaseUrl,
        fallback: 'http://10.0.2.2:3000',
      );

  static String get env =>
      _read(_kEnv, dartDefine: _defineEnv, fallback: 'dev');

  static String get apiBaseUrl {
    var url = _rawBaseUrl;
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!url.endsWith('/api/v1')) url = '$url/api/v1';
    return url;
  }

  /// Returns the bare scheme + host (+ port) of the backend, with no path.
  /// Used as the Socket.IO connection target so the `/chat` namespace can be
  /// appended cleanly without colliding with `/api/v1`.
  ///
  /// We rely on `Uri` parsing rather than substring math because the previous
  /// `indexOf('/api')` approach incorrectly matched the `/a` that appears
  /// inside `://api.zenno.dev`, producing a malformed origin like `https:/`.
  static String get socketOrigin {
    final uri = Uri.parse(_rawBaseUrl);
    final buffer = StringBuffer('${uri.scheme}://${uri.host}');
    if (uri.hasPort) buffer.write(':${uri.port}');
    return buffer.toString();
  }

  static bool get isDev => env == 'dev';
  static bool get isProd => env == 'prod';
}
