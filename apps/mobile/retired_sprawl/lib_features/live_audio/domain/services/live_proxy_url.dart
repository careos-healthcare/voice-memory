/// Normalizes backend mint responses to a WebSocket scheme.
///
/// The session mint route may return an HTTP(S) origin; clients must connect
/// with `ws`/`wss`.
String normalizeProxyWebSocketUrl(String url) {
  final uri = Uri.parse(url);
  final scheme = switch (uri.scheme) {
    'http' => 'ws',
    'https' => 'wss',
    _ => uri.scheme,
  };
  if (scheme == uri.scheme) return url;
  return uri.replace(scheme: scheme).toString();
}

/// Redacts sensitive query params before logging a WebSocket URL.
String redactProxyWebSocketUrlForLog(String url) {
  final uri = Uri.parse(normalizeProxyWebSocketUrl(url));
  final redactedQuery = {
    for (final entry in uri.queryParameters.entries)
      entry.key: entry.key == 'sessionToken' ? '[redacted]' : entry.value,
  };
  return uri.replace(queryParameters: redactedQuery).toString();
}