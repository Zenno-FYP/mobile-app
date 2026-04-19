/// Centralised duration formatting that mirrors the website helpers
/// (`formatDurationFromHours` and `formatSkillDuration` in
/// `ProjectDetailPage.tsx`). The whole app should use these so that
/// "1.2h", "23m", "45s" stay consistent everywhere.
///
/// Rule (matches the web):
///   ≥ 1 h         → "h.NN h" (or "h.N h" once we cross 10h)
///   ≥ 1 min       → "Nm" (rounded)
///   < 1 min, > 0  → "Ns" (at least 1s)
///   ≤ 0           → "0s"
library;

/// Format a value already expressed in hours.
String formatHours(double h) {
  if (!h.isFinite || h <= 0) return '0s';
  final sec = h * 3600;
  if (sec < 60) return '${sec.round().clamp(1, 1 << 31)}s';
  if (h < 1) return '${(sec / 60).round()}m';
  return h >= 10 ? '${h.toStringAsFixed(1)}h' : '${h.toStringAsFixed(2)}h';
}

/// Format a value expressed in seconds. Useful for skill timers where the
/// API ships precise seconds and rounding to hours would print "0.0h".
String formatSeconds(double sec) {
  if (!sec.isFinite || sec <= 0) return '—';
  if (sec < 60) return '${sec.round().clamp(1, 1 << 31)}s';
  if (sec < 3600) return '${(sec / 60).round()}m';
  final h = sec / 3600;
  return h < 10 ? '${h.toStringAsFixed(2)}h' : '${h.toStringAsFixed(1)}h';
}
