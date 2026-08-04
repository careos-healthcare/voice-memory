// Named parameters cannot expose private field names.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import '../../features/archive_ownership/archive_scope_paths.dart';
import '../../features/archive_ownership/local_archive_identity.dart';
import '../../features/archive_semantic_search/archive_semantic_search_engine.dart';
import '../../features/archive_semantic_search/semantic_index_store.dart';
import '../../features/explainable_conclusion/explainability_history_store.dart';
import '../../storage/encrypted_json_file_store.dart';
import '../../storage/journal_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import '../journal_service.dart';
import 'core_services.dart';
import 'privacy_services.dart';
import 'v1_composition_config.dart';

final class ArchiveServices {
  ArchiveServices._(this._core, this._privacy, this._config, this._scope);

  final CoreServices _core;
  final PrivacyServices _privacy;
  final V1CompositionConfig _config;
  _ArchiveScope _scope;

  JournalStore get journalStore => _scope.journalStore;
  JournalService get journal => _scope.journal;
  SemanticIndexStore get archiveSemanticIndexStore => _scope.semanticIndex;
  ArchiveSemanticSearchEngine get archiveSemanticSearch => _scope.search;
  ExplainabilityHistoryStore get explainabilityHistoryStore =>
      _scope.explainability;
  LocalArchiveIdentity get identity => _scope.identity;

  /// True once the semantic index object exists for the active scope. Capture
  /// never needs it: the journal's post-persist hook creates it after a save.
  bool get isSemanticIndexInitialized => _scope.hasSemanticIndex;

  static Future<ArchiveServices> create(
    CoreServices core,
    PrivacyServices privacy,
    V1CompositionConfig config,
    LocalArchiveIdentity identity,
  ) async {
    core.activateDisclosureArchive(identity.archiveId);
    final scope = await _openScope(core, privacy, config, identity);
    return ArchiveServices._(core, privacy, config, scope);
  }

  Future<void> activate(LocalArchiveIdentity identity) async {
    if (_scope.identity.archiveId == identity.archiveId) return;
    final next = await _openScope(_core, _privacy, _config, identity);
    final previous = _scope;
    _core.activateDisclosureArchive(identity.archiveId);
    _scope = next;
    await previous.dispose();
  }

  /// Warms the derived local stores after the first frame.
  ///
  /// Reading and validating the encrypted semantic index is real disk work that
  /// no capture step depends on, so it happens here rather than during the
  /// first search or the first save.
  Future<void> activateDerivedStores() async {
    try {
      await _scope.semanticIndex.loadSnapshot();
    } on Object {
      // A damaged index rebuilds on the next journal reconciliation.
    }
    try {
      await _scope.explainability.all();
    } on Object {
      // Explainability history is advisory; a read failure changes nothing.
    }
  }

  static Future<_ArchiveScope> _openScope(
    CoreServices core,
    PrivacyServices privacy,
    V1CompositionConfig config,
    LocalArchiveIdentity identity,
  ) async {
    final keyStore = config.testMode
        ? InMemoryPrivateDataEncryptionKeyStore()
        : SecurePrivateDataEncryptionKeyStore(secure: core.secureStorage);
    final scopePath = ArchiveScopePaths.scopeDirectory(
      basePath: config.basePath,
      identity: identity,
    );
    final journalPath = config.journalPath != null && config.testMode
        ? config.journalPath!
        : ArchiveScopePaths.journalPath(
            basePath: config.basePath,
            identity: identity,
          );
    final journalStore = await JournalStore.open(
      journalPath,
      encryptAtRest: !config.testMode || config.secureStorage != null,
      secureStorage: config.testMode
          ? config.secureStorage
          : core.secureStorage,
      syncDeviceIdProvider: config.testMode
          ? () async => 'test-device'
          : core.deviceIds.getOrCreate,
      ownerArchiveId: identity.archiveId,
    );
    final scope = _ArchiveScope(
      identity: identity,
      journalStore: journalStore,
      journal: JournalService(journalStore),
      buildSemanticIndex: () => SemanticIndexStore(
        storage: EncryptedJsonFileStore(
          file: File('$scopePath/semantic_archive_index.enc'),
          keyStore: keyStore,
        ),
      ),
      buildExplainability: () => ExplainabilityHistoryStore(
        file: File('$scopePath/explainability_history.enc'),
        keyStore: keyStore,
      ),
    );

    journalStore.configurePostPersistHook((entries) async {
      try {
        await scope.semanticIndex.reconcile(entries);
      } on Object {
        // Search indexing retries on a later journal reconciliation.
      }
    });
    return scope;
  }

  Future<void> dispose() => _scope.dispose();
}

/// One archive identity's stores.
///
/// The semantic index, its search engine and the explainability history are
/// created on first use so an interactive Record surface never waits on them.
final class _ArchiveScope {
  _ArchiveScope({
    required this.identity,
    required this.journalStore,
    required this.journal,
    required SemanticIndexStore Function() buildSemanticIndex,
    required ExplainabilityHistoryStore Function() buildExplainability,
  }) : _buildSemanticIndex = buildSemanticIndex,
       _buildExplainability = buildExplainability;

  final LocalArchiveIdentity identity;
  final JournalStore journalStore;
  final JournalService journal;
  final SemanticIndexStore Function() _buildSemanticIndex;
  final ExplainabilityHistoryStore Function() _buildExplainability;

  SemanticIndexStore? _semanticIndex;
  ArchiveSemanticSearchEngine? _search;
  ExplainabilityHistoryStore? _explainability;

  bool get hasSemanticIndex => _semanticIndex != null;

  SemanticIndexStore get semanticIndex =>
      _semanticIndex ??= _buildSemanticIndex();

  ArchiveSemanticSearchEngine get search =>
      _search ??= ArchiveSemanticSearchEngine(
        journalStore: journalStore,
        indexStore: semanticIndex,
      );

  ExplainabilityHistoryStore get explainability =>
      _explainability ??= _buildExplainability();

  Future<void> dispose() async {
    journalStore.configurePostPersistHook(null);
    _search?.dispose();
    await _semanticIndex?.dispose();
    await _explainability?.dispose();
  }
}
