import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/private_data_encryption_key_store.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../insight_feedback/insight_feedback_store.dart';
import 'change_resurfacing.dart';
import 'change_thread_correction.dart';
import 'change_thread_projection.dart';
import 'change_thread_store.dart';

/// Everything the Changes surface needs from one pass over the archive.
class ChangesSnapshot {
  ChangesSnapshot({
    required this.projection,
    required this.resurfacing,
    required Iterable<ChangeThreadCorrection> corrections,
    required Iterable<JournalEntry> entries,
  }) : corrections = List.unmodifiable(corrections),
       entries = List.unmodifiable(entries);

  ChangesSnapshot.empty({DateTime? now})
    : projection = const ChangeThreadProjection.empty(),
      resurfacing = ChangeResurfacingContext(
        liveEntryIds: const [],
        surfacingModes: const {},
        now: now ?? DateTime.now(),
      ),
      corrections = const [],
      entries = const [];

  final ChangeThreadProjection projection;
  final ChangeResurfacingContext resurfacing;
  final List<ChangeThreadCorrection> corrections;
  final List<JournalEntry> entries;

  bool get hasMoments =>
      projection.threads.isNotEmpty || projection.ungroupedEvents.isNotEmpty;
}

/// Resolves the current archive's thread store and keeps Changes reading from
/// exactly one place.
///
/// The store lives beside that archive's journal, so switching accounts swaps
/// the whole file rather than filtering a shared one.
abstract final class ChangeThreadRepository {
  static ChangeThreadStore? _store;
  static String? _storeArchiveId;

  static ChangeThreadStore? storeOrNull() {
    if (!AppServices.isInitialized) return null;
    final journal = AppServices.instance.journalStore;
    final archiveId = journal.ownerArchiveId;
    if (_store != null && _storeArchiveId == archiveId) return _store;
    _store = ChangeThreadStore(
      file: File('${journal.file.parent.path}/${ChangeThreadStore.fileName}'),
      keyStore: _keyStore(),
      archiveId: archiveId,
    );
    _storeArchiveId = archiveId;
    return _store;
  }

  /// Re-derives threads from the archive's own moments and conclusions, then
  /// writes the result back so the next cold start opens on the same threads.
  ///
  /// Corrections are read first and replayed by the projector, so a rename or
  /// a split is never lost to a later re-projection.
  static Future<ChangeThreadProjection> refresh() async =>
      (await load()).projection;

  /// [refresh], plus the corrections and live-moment context the Changes
  /// surface needs to show review history and decide on resurfacing.
  static Future<ChangesSnapshot> load({DateTime? now}) async {
    final store = storeOrNull();
    if (store == null) return ChangesSnapshot.empty(now: now);
    final services = AppServices.instance;
    final archiveId = services.journalStore.ownerArchiveId;
    await InsightFeedbackStore.ensureLoaded();
    final saved = await store.read();
    final entries = await services.journal.loadAll();
    final history = await services.explainabilityHistoryStore.all();
    final projection = ChangeThreadProjector.project(
      archiveId: archiveId,
      entries: entries,
      conclusions: [
        ...history.map((item) => item.conclusion),
        ...entries
            .map((entry) => entry.reflection.explainableConclusion)
            .whereType<ExplainableConclusion>(),
      ],
      feedback: InsightFeedbackStore.cached,
      corrections: saved.corrections,
      existingThreads: saved.threads,
    );
    await store.save(projection);
    return ChangesSnapshot(
      projection: projection,
      resurfacing: ChangeResurfacingContext.fromEntries(
        entries.where((entry) => entry.ownerArchiveId == archiveId),
        now: now ?? DateTime.now().toUtc(),
      ),
      corrections: saved.corrections,
      entries: entries,
    );
  }

  /// Records [correction] and returns the reprojected threads.
  static Future<ChangeThreadProjection> correct(
    ChangeThreadCorrection correction,
  ) async {
    final store = storeOrNull();
    if (store == null) return const ChangeThreadProjection.empty();
    await store.addCorrection(correction);
    return refresh();
  }

  /// [correct], returning the full snapshot so the caller keeps its review
  /// history and resurfacing context in step with the new projection.
  static Future<ChangesSnapshot> correctAndLoad(
    ChangeThreadCorrection correction, {
    DateTime? now,
  }) async {
    final store = storeOrNull();
    if (store == null) return ChangesSnapshot.empty(now: now);
    await store.addCorrection(correction);
    return load(now: now);
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
  }
}
