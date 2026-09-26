import 'dart:convert';

import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Salt and Argon2id parameters published for an account.
class RemoteSyncParams {
  const RemoteSyncParams({
    required this.salt,
    required this.kdf,
    required this.wrappedByPassphrase,
    required this.wrappedByRecovery,
    required this.createdAt,
  });

  factory RemoteSyncParams.fromJson(Map<String, Object?> json) {
    final wrapped = json['wrappedByPassphrase'];
    final recovery = json['wrappedByRecovery'];
    if (wrapped is! Map) {
      throw const FormatException('Sync parameters did not include a wrapped key.');
    }
    final passphraseWrap = WrappedAccountKey.fromJson(
      Map<String, Object?>.from(wrapped),
    );
    final salt = json['salt'];
    if (salt is String && salt.isNotEmpty && salt != passphraseWrap.salt) {
      throw const AccountKeyUnlockFailed();
    }
    return RemoteSyncParams(
      salt: passphraseWrap.salt,
      kdf: passphraseWrap.kdf,
      wrappedByPassphrase: passphraseWrap,
      wrappedByRecovery: recovery is Map
          ? WrappedAccountKey.fromJson(Map<String, Object?>.from(recovery))
          : passphraseWrap,
      createdAt:
          DateTime.tryParse('${json['createdAt']}')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  final String salt;
  final AccountKdfParams kdf;
  final WrappedAccountKey wrappedByPassphrase;
  final WrappedAccountKey wrappedByRecovery;
  final DateTime createdAt;
}

/// Loads the account's existing KDF salt before a second device derives a key.
class AccountSyncKeyImport {
  const AccountSyncKeyImport._();

  static const paramsPath = '/api/sync/params';
  static const keysPath = '/api/sync/keys';

  /// Fetches `/api/sync/params`. Returns null when this account has not published one.
  static Future<RemoteSyncParams?> loadParams({
    Future<Map<String, Object?>?> Function()? fetchParams,
  }) async {
    final raw = await (fetchParams ?? _fetchParams)();
    if (raw == null) return null;
    return RemoteSyncParams.fromJson(raw);
  }

  /// Fetches `/api/sync/params`, then unwraps with that salt. A missing record
  /// does not mint a new account key.
  static Future<({List<int> accountKey, AccountKeyBundle bundle})>
  importExisting({
    required String passphrase,
    Future<Map<String, Object?>?> Function()? fetchParams,
    Future<void> Function(AccountKeyBundle bundle)? store,
    bool persist = true,
  }) async {
    final params = await loadParams(fetchParams: fetchParams);
    if (params == null) throw const AccountKeyUnlockFailed();
    return unlockWithParams(
      passphrase: passphrase,
      params: params,
      store: store,
      persist: persist,
    );
  }

  /// Derives with [params.salt] and stores that wrapped key on this phone.
  static Future<({List<int> accountKey, AccountKeyBundle bundle})>
  unlockWithParams({
    required String passphrase,
    required RemoteSyncParams params,
    Future<void> Function(AccountKeyBundle bundle)? store,
    bool persist = true,
  }) async {
    final accountKey = await AccountSyncKey.unwrap(
      wrapped: params.wrappedByPassphrase,
      secret: passphrase,
    );
    final bundle = AccountKeyBundle(
      wrappedByPassphrase: params.wrappedByPassphrase,
      wrappedByRecovery: params.wrappedByRecovery,
      createdAt: params.createdAt,
    );
    if (persist) {
      final save = store ?? AccountSyncKey.storeBundle;
      await save(bundle);
    }
    return (accountKey: accountKey, bundle: bundle);
  }

  /// Publishes the salt and wrapped key so another device can fetch them.
  static Future<void> publish(
    AccountKeyBundle bundle, {
    Future<void> Function(Map<String, Object> body)? post,
  }) async {
    final body = <String, Object>{
      'wrappedByPassphrase': bundle.wrappedByPassphrase.toJson(),
      'wrappedByRecovery': bundle.wrappedByRecovery.toJson(),
      'kdfParams': bundle.wrappedByPassphrase.kdf.toJson(),
      'createdAt': bundle.createdAt.toUtc().toIso8601String(),
    };
    final send = post ?? _postKeys;
    await send(body);
  }

  static Future<Map<String, Object?>?> _fetchParams() async {
    if (!AppServices.isInitialized) return null;
    final result = await AppServices.instance.httpTransport.get(paramsPath);
    final response = result.valueOrNull;
    if (response == null || response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return Map<String, Object?>.from(decoded);
  }

  static Future<void> _postKeys(Map<String, Object> body) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.httpTransport.post(keysPath, body: body);
  }
}
