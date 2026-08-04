import 'dart:async';
import 'dart:io';

import '../../../storage/encrypted_json_file_store.dart';
import '../../../storage/private_data_encryption_key_store.dart';
import '../domain/access_policy_engine.dart';
import '../domain/product_value_delivery_ledger.dart';

/// Durable, archive-scoped home for the free-value delivery ledger.
///
/// Each archive keeps its own ledger row. Proof delivered inside one archive
/// can never close the free slot of another, even if two archives end up
/// sharing a file after a partial migration.
class ProductValueDeliveryLedgerStore {
  ProductValueDeliveryLedgerStore({
    required File file,
    required PrivateDataEncryptionKeyStore keyStore,
    required this.archiveId,
    DateTime Function()? clock,
  }) : assert(archiveId != '', 'A delivery ledger must belong to an archive.'),
       _storage = EncryptedJsonFileStore(file: file, keyStore: keyStore),
       _clock = clock ?? DateTime.now;

  static const storeVersion = 1;
  static const fileName = 'product_value_delivery_ledger.enc';

  final EncryptedJsonFileStore _storage;
  final String archiveId;
  final DateTime Function() _clock;
  Future<void> _pending = Future.value();

  File get encryptedFile => _storage.file;

  Future<ProductValueDeliveryLedger> read() => _serialized(
    () async =>
        (await _readAll())[archiveId] ??
        const ProductValueDeliveryLedger.empty(),
  );

  /// Commercial state for the access policy, derived only from real deliveries.
  Future<ProductValueState> productValue() async => (await read()).productValue;

  /// Records that a validated artifact reached the user.
  ///
  /// Safe to call on every render: a repeat of the same artifact reports
  /// [ProductValueDeliveryRejection.alreadyDelivered] and leaves the ledger
  /// untouched rather than spending the slot twice.
  Future<ProductValueDeliveryOutcome> recordDelivered(
    ProductValueDeliveryAttempt attempt,
  ) => _serialized(() async {
    final all = await _readAll();
    final current = all[archiveId] ?? const ProductValueDeliveryLedger.empty();
    final outcome = ProductValueDeliveryGate.record(
      ledger: current,
      attempt: attempt,
      now: _clock().toUtc(),
    );
    if (!outcome.consumedFreeProof) return outcome;
    await _writeAll({...all, archiveId: outcome.ledger});
    return outcome;
  });

  Future<void> clear() => _serialized(() async {
    final all = await _readAll();
    await _writeAll({...all}..remove(archiveId));
  });

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, ProductValueDeliveryLedger>> _readAll() async {
    final raw = await _storage.readJson();
    if (raw is! Map) return {};
    final json = Map<String, dynamic>.from(raw);
    if (json['storeVersion'] != storeVersion) return {};
    final archives = json['archives'];
    if (archives is! Map) return {};
    return {
      for (final entry in archives.entries)
        entry.key.toString(): ProductValueDeliveryLedger.fromJson(entry.value),
    };
  }

  Future<void> _writeAll(Map<String, ProductValueDeliveryLedger> all) =>
      _storage.writeJson({
        'storeVersion': storeVersion,
        'archives': {
          for (final entry in all.entries) entry.key: entry.value.toJson(),
        },
      });
}
