import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../services/app_services.dart';
import '../../../storage/private_data_encryption_key_store.dart';
import '../../explainable_conclusion/explainable_conclusion_validator.dart';
import '../../insight_feedback/insight_feedback_store.dart';
import '../domain/access_policy_engine.dart';
import '../domain/product_value_delivery_ledger.dart';
import 'product_value_delivery_ledger_store.dart';

/// The app-layer entry point the UI calls the moment an artifact is on screen.
///
/// Nothing else in the app may mark free value as delivered. Generation,
/// validation and persistence all happen before this point; this is the only
/// place that observes the last missing condition — that the user actually saw
/// the thing ArchiveMe promised them.
abstract final class ProductValueDeliveryRecorder {
  static ProductValueDeliveryLedgerStore? _store;
  static String? _storeArchiveId;
  static ProductValueDeliveryLedger _cached =
      const ProductValueDeliveryLedger.empty();

  /// Last known ledger. Synchronous so access decisions taken during a build
  /// never block on disk.
  static ProductValueDeliveryLedger get cached => _cached;

  static ProductValueState get productValue => _cached.productValue;

  static Future<ProductValueDeliveryLedger> ensureLoaded() async {
    final store = _resolveStore();
    if (store == null) return _cached;
    _cached = await store.read();
    return _cached;
  }

  /// Records that [validated] was rendered to the user in [archiveId]'s
  /// archive, persisting the artifact first so a delivery is never claimed for
  /// something that was not durably written.
  static Future<ProductValueDeliveryOutcome> markRendered(
    ValidatedExplainableConclusion validated,
  ) async {
    final store = _resolveStore();
    if (store == null) {
      return const ProductValueDeliveryOutcome(
        ledger: ProductValueDeliveryLedger.empty(),
        consumedFreeProof: false,
        kind: null,
        rejection: ProductValueDeliveryRejection.persistenceFailed,
      );
    }
    final services = AppServices.instance;
    final conclusion = validated.value;

    var persisted = false;
    try {
      await services.explainabilityHistoryStore.appendIfAbsent(validated);
      persisted = true;
    } on Object {
      // A durable write is a precondition for delivery, so a failure here
      // leaves the free slot open rather than silently spending it.
    }

    final transcripts = <String, String>{};
    final deleted = <String>{};
    for (final entryId in conclusion.evidence.map((item) => item.entryId)) {
      if (transcripts.containsKey(entryId) || deleted.contains(entryId)) {
        continue;
      }
      try {
        final entry = await services.journalStore.getById(entryId);
        if (entry == null || entry.isDeleted) {
          deleted.add(entryId);
          continue;
        }
        transcripts[entryId] = entry.transcript;
      } on Object {
        deleted.add(entryId);
      }
    }

    final outcome = await store.recordDelivered(
      ProductValueDeliveryAttempt(
        candidate: conclusion,
        canonicalTranscripts: transcripts,
        generationSucceeded: true,
        artifactPersisted: persisted,
        rendered: true,
        feedback: InsightFeedbackStore.cached,
        deletedEntryIds: deleted,
      ),
    );
    if (outcome.consumedFreeProof) _cached = outcome.ledger;
    return outcome;
  }

  static ProductValueDeliveryLedgerStore? _resolveStore() {
    if (!AppServices.isInitialized) return null;
    final journal = AppServices.instance.journalStore;
    final archiveId = journal.ownerArchiveId;
    if (_store != null && _storeArchiveId == archiveId) return _store;
    _store = ProductValueDeliveryLedgerStore(
      file: File(
        '${journal.file.parent.path}/'
        '${ProductValueDeliveryLedgerStore.fileName}',
      ),
      keyStore: _keyStore(),
      archiveId: archiveId,
    );
    _storeArchiveId = archiveId;
    _cached = const ProductValueDeliveryLedger.empty();
    return _store;
  }

  static PrivateDataEncryptionKeyStore _keyStore() =>
      Platform.environment.containsKey('FLUTTER_TEST')
      ? InMemoryPrivateDataEncryptionKeyStore()
      : SecurePrivateDataEncryptionKeyStore(
          secure: AppServices.instance.secureStorage,
        );

  @visibleForTesting
  static void resetForTest() {
    _store = null;
    _storeArchiveId = null;
    _cached = const ProductValueDeliveryLedger.empty();
  }
}
