/// In-memory capture token — not persisted long-term.
class CaptureTokenCache {
  String? _token;
  DateTime? _expiresAt;

  String? get token => _token;

  bool get hasValidToken {
    if (_token == null || _expiresAt == null) return false;
    return DateTime.now().isBefore(_expiresAt!);
  }

  void setToken(String token, {required int expiresInSeconds}) {
    _token = token;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
  }

  void clear() {
    _token = null;
    _expiresAt = null;
  }
}