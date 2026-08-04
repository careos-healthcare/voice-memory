import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../features/export_backup/vault_format.dart';
import '../../features/whispering_vault/audio_vault_storage.dart';
import '../../services/ai/local_semantic_store.dart';
import '../../services/local_storage/browser_bridge_vault.dart';
import 'sanctuary_models.dart';

typedef SanctuaryKeyValidator = Future<bool> Function();
typedef SanctuaryCountLoader = Future<int> Function();

final class SanctuaryHealthEngine {
  SanctuaryHealthEngine({
    required this.root,
    required this.graphStore,
    required this.audioVault,
    required this.semanticStore,
    required this.browserVault,
    required this.privateKeyValid,
    required this.audioKeyValid,
    this.documentEmbeddingCount,
    Iterable<String>? sqlitePaths,
    DateTime Function()? clock,
  }) : sqlitePaths = List.unmodifiable(
         sqlitePaths ?? _defaultSqlitePaths(root.path),
       ),
       _clock = clock ?? DateTime.now;

  final Directory root;
  final PersonalKnowledgeGraphStore graphStore;
  final AudioVaultStorage audioVault;
  final LocalSemanticStore semanticStore;
  final BrowserBridgeVault browserVault;
  final SanctuaryKeyValidator privateKeyValid;
  final SanctuaryKeyValidator audioKeyValid;
  final SanctuaryCountLoader? documentEmbeddingCount;
  final List<String> sqlitePaths;
  final DateTime Function() _clock;

  Future<SanctuaryHealthReport> audit() async {
    final diagnostics = <SanctuaryDiagnostic>[];
    for (final databasePath in sqlitePaths) {
      diagnostics.add(_auditSqlite(databasePath));
    }
    diagnostics
      ..add(
        await _auditKey(
          'private-key',
          'AES-256 private-data key',
          privateKeyValid,
        ),
      )
      ..add(
        await _auditKey('audio-key', 'AES-256 audio-vault key', audioKeyValid),
      )
      ..add(_auditVectorIndex())
      ..addAll(await _auditBackupSnapshots())
      ..addAll(await _auditApexReports());

    final graph = await graphStore.load();
    final audio = await audioVault.list();
    final embeddingCount = await semanticStore.count();
    final documentEmbeddings = await documentEmbeddingCount?.call() ?? 0;
    final clipCount = browserVault.clipCount;
    final storage = [
      SanctuaryStorageMetric(
        kind: SanctuaryStorageKind.memoryGraph,
        bytes: await _bytesFor(const [
          'personal_knowledge_graph.enc',
          'temporal_graph_history.enc',
        ]),
        itemCount: graph.nodes.length + graph.edges.length,
        label: 'Memory Graph',
      ),
      SanctuaryStorageMetric(
        kind: SanctuaryStorageKind.whisperAudio,
        bytes: await _bytesFor(const [
          'whispering_vault.sqlite3',
          'whispering_vault.sqlite3-wal',
          'whispering_vault.sqlite3-shm',
        ]),
        itemCount: audio.length,
        label: 'Whispering Vault audio',
      ),
      SanctuaryStorageMetric(
        kind: SanctuaryStorageKind.embeddings,
        bytes: await _bytesFor(const [
          'hybrid_local_semantic.enc',
          'hybrid_local_semantic.sqlite3',
          'hybrid_local_semantic.sqlite3-wal',
          'hybrid_local_semantic.sqlite3-shm',
          'document_semantic_index.enc',
          'document_semantic.sqlite3',
          'document_semantic.sqlite3-wal',
          'document_semantic.sqlite3-shm',
        ]),
        itemCount: embeddingCount + documentEmbeddings,
        label: 'Local embeddings',
      ),
      SanctuaryStorageMetric(
        kind: SanctuaryStorageKind.browserClips,
        bytes: await _bytesFor(const [
          'browser_bridge.sqlite3',
          'browser_bridge.sqlite3-wal',
          'browser_bridge.sqlite3-shm',
        ]),
        itemCount: clipCount,
        label: 'Browser clips',
      ),
      SanctuaryStorageMetric(
        kind: SanctuaryStorageKind.backups,
        bytes: await _backupBytes(),
        itemCount: await _backupCount(),
        label: 'Encrypted backups',
      ),
    ];
    return SanctuaryHealthReport(
      generatedAt: _clock().toUtc(),
      diagnostics: List.unmodifiable(diagnostics),
      storage: List.unmodifiable(storage),
      cleanupRecommendations: List.unmodifiable(
        _recommend(
          storage,
          audio.length,
          embeddingCount + documentEmbeddings,
          clipCount,
        ),
      ),
    );
  }

  SanctuaryDiagnostic _auditSqlite(String databasePath) {
    final name = path.basename(databasePath);
    final file = File(databasePath);
    if (!file.existsSync()) {
      return SanctuaryDiagnostic(
        id: 'sqlite:$name',
        label: name,
        status: SanctuaryCheckStatus.unavailable,
        detail: 'Not created yet.',
      );
    }
    Database? database;
    try {
      database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
      final rows = database.select('PRAGMA quick_check(1)');
      final result = rows.isEmpty ? '' : '${rows.single.values.first}';
      return SanctuaryDiagnostic(
        id: 'sqlite:$name',
        label: name,
        status: result == 'ok'
            ? SanctuaryCheckStatus.healthy
            : SanctuaryCheckStatus.failed,
        detail: result == 'ok' ? 'SQLite integrity check passed.' : result,
      );
    } on Object {
      return SanctuaryDiagnostic(
        id: 'sqlite:$name',
        label: name,
        status: SanctuaryCheckStatus.failed,
        detail: 'Database could not be authenticated or opened.',
      );
    } finally {
      database?.close();
    }
  }

  Future<SanctuaryDiagnostic> _auditKey(
    String id,
    String label,
    SanctuaryKeyValidator validator,
  ) async {
    try {
      final valid = await validator();
      return SanctuaryDiagnostic(
        id: id,
        label: label,
        status: valid
            ? SanctuaryCheckStatus.healthy
            : SanctuaryCheckStatus.failed,
        detail: valid
            ? 'Valid 256-bit key material.'
            : 'Key is missing or malformed.',
      );
    } on Object {
      return SanctuaryDiagnostic(
        id: id,
        label: label,
        status: SanctuaryCheckStatus.failed,
        detail: 'Secure key validation failed.',
      );
    }
  }

  SanctuaryDiagnostic _auditVectorIndex() => SanctuaryDiagnostic(
    id: 'sqlite-vec',
    label: 'sqlite-vec semantic index',
    status: semanticStore.hasNativeVectorAcceleration
        ? SanctuaryCheckStatus.healthy
        : SanctuaryCheckStatus.warning,
    detail: semanticStore.hasNativeVectorAcceleration
        ? 'Native vector acceleration is loaded.'
        : 'Encrypted linear-search fallback is active; rebuild the vector index.',
  );

  Future<List<SanctuaryDiagnostic>> _auditBackupSnapshots() async {
    if (!await root.exists()) return const [];
    final result = <SanctuaryDiagnostic>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File ||
          (!entity.path.endsWith('.memoryvault') &&
              !entity.path.endsWith('.sanctuary-key'))) {
        continue;
      }
      final name = path.basename(entity.path);
      try {
        final bytes = await entity.readAsBytes();
        VaultEnvelope.fromBytes(bytes);
        result.add(
          SanctuaryDiagnostic(
            id: 'backup:$name',
            label: name,
            status: SanctuaryCheckStatus.healthy,
            detail:
                'AES-256-GCM envelope structure is valid; payload '
                'authentication occurs when the backup is unlocked.',
          ),
        );
      } on Object {
        result.add(
          SanctuaryDiagnostic(
            id: 'backup:$name',
            label: name,
            status: SanctuaryCheckStatus.failed,
            detail: 'Encrypted snapshot envelope is corrupt.',
          ),
        );
      }
    }
    return result;
  }

  Future<List<SanctuaryDiagnostic>> _auditApexReports() async {
    final directory = Directory(path.join(root.path, 'apex_audits'));
    if (!await directory.exists()) return const [];
    final result = <SanctuaryDiagnostic>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.apex-audit')) continue;
      final name = path.basename(entity.path);
      try {
        final value = jsonDecode(await entity.readAsString());
        if (value is! Map ||
            value['v'] != 1 ||
            base64Decode(value['n'] as String).length != 12 ||
            base64Decode(value['m'] as String).length != 16 ||
            base64Decode(value['c'] as String).isEmpty) {
          throw const FormatException('Invalid encrypted audit envelope.');
        }
        result.add(
          SanctuaryDiagnostic(
            id: 'apex:$name',
            label: name,
            status: SanctuaryCheckStatus.healthy,
            detail:
                'Encrypted Apex envelope structure is valid; payload '
                'authentication occurs when opened with the private key.',
          ),
        );
      } on Object {
        result.add(
          SanctuaryDiagnostic(
            id: 'apex:$name',
            label: name,
            status: SanctuaryCheckStatus.failed,
            detail: 'Encrypted Apex audit envelope is corrupt.',
          ),
        );
      }
    }
    return result;
  }

  Future<int> _bytesFor(List<String> names) async {
    var total = 0;
    for (final name in names) {
      final file = File(path.join(root.path, name));
      if (await file.exists()) total += await file.length();
    }
    return total;
  }

  Future<int> _backupBytes() async {
    var total = 0;
    if (!await root.exists()) return total;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          (entity.path.endsWith('.memoryvault') ||
              entity.path.endsWith('.sanctuary-key'))) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<int> _backupCount() async {
    var count = 0;
    if (!await root.exists()) return count;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          (entity.path.endsWith('.memoryvault') ||
              entity.path.endsWith('.sanctuary-key'))) {
        count++;
      }
    }
    return count;
  }
}

List<String> _defaultSqlitePaths(String root) => [
  for (final name in const [
    'hybrid_local_semantic.sqlite3',
    'document_semantic.sqlite3',
    'whispering_vault.sqlite3',
    'browser_bridge.sqlite3',
    'autonomous_muse.sqlite3',
    'horizon_lab.sqlite3',
    'life_story_replay.sqlite3',
    'persona_forge.sqlite3',
    'cognitive_metrics.sqlite3',
    'mesh_incoming.sqlite3',
    'e2ee_sync_outbox.db',
    'shared_vault/shared_vault_outbox.db',
    'transcription_queue/transcription_jobs.sqlite3',
  ])
    path.join(root, name),
];

List<String> _recommend(
  List<SanctuaryStorageMetric> storage,
  int audioCount,
  int embeddingCount,
  int clipCount,
) {
  final recommendations = <String>[];
  final byKind = {for (final item in storage) item.kind: item};
  if ((byKind[SanctuaryStorageKind.whisperAudio]?.bytes ?? 0) >
      250 * 1024 * 1024) {
    recommendations.add(
      'Review expired Whispering Vault audio while retaining transcripts.',
    );
  }
  if (embeddingCount > 15000) {
    recommendations.add(
      'Rebuild the local sqlite-vec index to compact stale embeddings.',
    );
  }
  if (clipCount > 1000) {
    recommendations.add('Archive old browser clips that are no longer active.');
  }
  if (audioCount == 0 && embeddingCount == 0 && clipCount == 0) {
    recommendations.add('No cleanup is currently recommended.');
  }
  return recommendations;
}
