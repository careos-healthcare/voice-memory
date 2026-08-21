import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Identifies which on-device storage namespace a piece of private data
/// belongs to: the signed-out "guest" namespace, or one namespace per
/// authenticated account. Namespaces are physically separate directories
/// (see `AppStoragePaths`/`AppServices`) and separate encryption-key
/// aliases (see `PrivateDataEncryptionKeyStore.keyAlias`) — never a shared
/// file filtered at read time. This is what makes account isolation a
/// storage-level guarantee rather than an application-level filter.
class AccountNamespace {
  const AccountNamespace._(this.key);

  /// Directory-safe, opaque namespace key. Never a raw user id or email —
  /// see [forUserId]. Safe to use as a path segment and as a
  /// `PrivateDataEncryptionKeyStore` key alias.
  final String key;

  /// The signed-out / not-yet-migrated namespace. Data created before a
  /// user ever signs in (or while intentionally staying signed out) lives
  /// here. This is a fixed, non-identifying literal — not a hash of
  /// anything — since "guest" itself carries no personal information.
  static const guest = AccountNamespace._('guest');

  static AccountNamespace forUserId(String userId) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    final digest = sha256.convert(
      utf8.encode('archiveme-account-ns-v1:$trimmed'),
    );
    // 24 hex chars (96 bits) is short enough to be a friendly directory
    // name and long enough that collisions are not a practical concern.
    return AccountNamespace._(digest.toString().substring(0, 24));
  }

  /// Restores a persisted namespace key (guest or hashed account id).
  static AccountNamespace fromStorageKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty || trimmed == guest.key) {
      return guest;
    }
    return AccountNamespace._(trimmed);
  }

  @override
  bool operator ==(Object other) =>
      other is AccountNamespace && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'AccountNamespace($key)';
}