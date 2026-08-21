import 'package:flutter/foundation.dart';

/// Holds the SQLCipher passphrase only in RAM while the database is unlocked.
class SecureSqliteSession extends ChangeNotifier {
  String? _passphrase;

  bool get isUnlocked => _passphrase != null && _passphrase!.isNotEmpty;

  String? get passphrase => _passphrase;

  void unlock(String passphrase) {
    if (passphrase.trim().isEmpty) {
      throw ArgumentError('passphrase must not be empty');
    }
    _passphrase = passphrase;
    notifyListeners();
  }

  /// Wipes the in-memory decryption material.
  void lock() {
    if (_passphrase == null) return;
    _passphrase = null;
    notifyListeners();
  }

  String requirePassphrase() {
    final value = _passphrase;
    if (value == null || value.isEmpty) {
      throw StateError('Secure SQLite session is locked');
    }
    return value;
  }

  @visibleForTesting
  void resetForTest() {
    _passphrase = null;
  }
}
