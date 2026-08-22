import 'package:archiveme_mobile/core/network/http_transport.dart' show HttpTransport;

/// Cooperative cancellation for in-flight HTTP requests.
///
/// Checked by [HttpTransport] before and after each request. Register tokens
/// with [NetworkRequestScope] and call [NetworkRequestScope.cancelAll] on
/// sign-out or account namespace switches.
class NetworkCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Tracks active cancel tokens for an app/account session.
class NetworkRequestScope {
  final Set<NetworkCancelToken> _tokens = {};

  NetworkCancelToken register() {
    final token = NetworkCancelToken();
    _tokens.add(token);
    return token;
  }

  void release(NetworkCancelToken token) => _tokens.remove(token);

  void cancelAll() {
    for (final token in _tokens.toList()) {
      token.cancel();
    }
    _tokens.clear();
  }
}