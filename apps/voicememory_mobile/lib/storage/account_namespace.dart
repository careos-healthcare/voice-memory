import 'package:crypto/crypto.dart';
import 'dart:convert';

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

  /// Deterministic, opaque namespace for an authenticated account. Hashing
  /// (rather than using the raw id) means the on-device directory listing,
  /// crash logs, backups, or a shared/rooted device never expose the
  /// account's real server-assigned id or email in a filename — even
  /// though the id itself is not usually secret, this is defense in depth
  /// and matches the "no raw ids in filenames" requirement. Deterministic:
  /// the same [userId] always maps to the same namespace, so re-signing
  /// into the same account on the same device reuses its existing data
  /// instead of creating a duplicate namespace.
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

  @override
  bool operator ==(Object other) =>
      other is AccountNamespace && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'AccountNamespace($key)';
}
