import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../models/journal_entry.dart';
import '../../services/ai/local_semantic_store.dart';
import '../../services/security/biometric_vault_service.dart';
import '../../storage/journal_store.dart';
import '../../services/privacy/audio_vault_service.dart';
import '../ai_engines/models/ai_explainability.dart';
import '../ai_engines/models/hypothesis_evolution.dart';
import '../semantic_clusters/semantic_cluster.dart';
import '../semantic_clusters/semantic_cluster_store.dart';

typedef MarkdownExportShare = Future<void> Function(String zipPath);
typedef MarkdownExportTempDirectory = Future<Directory> Function();
typedef JournalEntriesLoader = Future<List<JournalEntry>> Function();
typedef ManualGraphLoader = Future<PersonalKnowledgeGraph> Function();
typedef ActiveHypothesesLoader = Future<List<HypothesisEvolution>> Function();
typedef SemanticClustersLoader = Future<List<SemanticCluster>> Function();
typedef KnowledgeGraphLoader = Future<PersonalKnowledgeGraph> Function();

enum MarkdownExportFailure {
  explicitUserActionRequired,
  biometricDenied,
  exportFailed,
}

final class MarkdownExportResult {
  const MarkdownExportResult.success({required this.entryCount})
    : failure = null;

  const MarkdownExportResult.failure(this.failure) : entryCount = 0;

  final MarkdownExportFailure? failure;
  final int entryCount;

  bool get succeeded => failure == null;
}

abstract interface class MarkdownExportAuthorization {
  /// Performs a fresh device-owner check immediately before plaintext is read.
  Future<bool> reauthenticate();
}

final class BiometricVaultMarkdownExportAuthorization
    implements MarkdownExportAuthorization {
  BiometricVaultMarkdownExportAuthorization(this.vault);

  final BiometricVaultService vault;

  @override
  Future<bool> reauthenticate() async {
    return vault.reauthenticateAndUnlock(
      reason: 'Confirm your identity to export readable archive data',
    );
  }
}

enum AttachmentExportKind { audio, image }

final class AttachmentExportRequest {
  const AttachmentExportRequest({
    required this.entryId,
    required this.kind,
    required this.relativePath,
    required this.mimeType,
    this.attachmentId,
  });

  final String entryId;
  final String? attachmentId;
  final AttachmentExportKind kind;
  final String relativePath;
  final String mimeType;
}

/// Optional source of plaintext media that was separately authorized by the
/// user. Implementations must return newly-owned, mutable bytes.
abstract interface class AttachmentExportSource {
  Future<Uint8List?> loadAuthorizedPlaintext(AttachmentExportRequest request);
}

final class AudioVaultAttachmentExportSource implements AttachmentExportSource {
  const AudioVaultAttachmentExportSource({
    required JournalStore journalStore,
    required AudioVaultService audioVault,
  }) : // Public named parameters cannot expose private field names.
       // ignore: prefer_initializing_formals
       _journalStore = journalStore,
       // ignore: prefer_initializing_formals
       _audioVault = audioVault;

  final JournalStore _journalStore;
  final AudioVaultService _audioVault;

  @override
  Future<Uint8List?> loadAuthorizedPlaintext(
    AttachmentExportRequest request,
  ) async {
    if (request.kind != AttachmentExportKind.audio) return null;
    final entry = await _journalStore.getById(request.entryId);
    final reference = entry?.localAudioVaultRef?.trim();
    if (reference == null ||
        reference.isEmpty ||
        !_audioVault.isVaultReference(reference)) {
      return null;
    }
    return _audioVault.readPlaintextBytes(reference);
  }
}

/// User-initiated, biometric-gated export of human-readable archive data.
///
/// This service deliberately has no scheduler/background entry point. Callers
/// must pass [explicitUserAction] for every export invocation.
final class MarkdownExportService {
  MarkdownExportService({
    JournalStore? journalStore,
    LocalSemanticStore? localSemanticStore,
    SemanticClusterStore? semanticClusterStore,
    PersonalKnowledgeGraphStore? knowledgeGraphStore,
    JournalEntriesLoader? loadEntries,
    ManualGraphLoader? loadManualGraph,
    ActiveHypothesesLoader? loadActiveHypotheses,
    SemanticClustersLoader? loadSemanticClusters,
    KnowledgeGraphLoader? loadKnowledgeGraph,
    required this.authorization,
    this.attachmentSource,
    MarkdownExportShare? share,
    MarkdownExportTempDirectory? temporaryDirectory,
    DateTime Function()? clock,
  }) : _loadEntries =
           loadEntries ??
           (journalStore ??
                   (throw ArgumentError(
                     'A JournalStore or loader is required.',
                   )))
               .loadAll,
       _loadManualGraph =
           loadManualGraph ??
           (localSemanticStore ??
                   (throw ArgumentError(
                     'A LocalSemanticStore or manual graph loader is required.',
                   )))
               .manualGraph,
       _loadActiveHypotheses =
           loadActiveHypotheses ??
           (localSemanticStore ??
                   (throw ArgumentError(
                     'A LocalSemanticStore or hypothesis loader is required.',
                   )))
               .activeHypotheses,
       _loadSemanticClusters =
           loadSemanticClusters ??
           (semanticClusterStore ??
                   (throw ArgumentError(
                     'A SemanticClusterStore or loader is required.',
                   )))
               .list,
       _loadKnowledgeGraph =
           loadKnowledgeGraph ??
           (knowledgeGraphStore ??
                   (throw ArgumentError(
                     'A PersonalKnowledgeGraphStore or loader is required.',
                   )))
               .load,
       _share = share ?? _shareWithPlatform,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  final JournalEntriesLoader _loadEntries;
  final ManualGraphLoader _loadManualGraph;
  final ActiveHypothesesLoader _loadActiveHypotheses;
  final SemanticClustersLoader _loadSemanticClusters;
  final KnowledgeGraphLoader _loadKnowledgeGraph;
  final MarkdownExportAuthorization authorization;
  final AttachmentExportSource? attachmentSource;
  final MarkdownExportShare _share;
  final MarkdownExportTempDirectory _temporaryDirectory;
  final DateTime Function() _clock;

  Future<MarkdownExportResult> export({
    required bool explicitUserAction,
  }) async {
    if (!explicitUserAction) {
      return const MarkdownExportResult.failure(
        MarkdownExportFailure.explicitUserActionRequired,
      );
    }
    if (!await authorization.reauthenticate()) {
      return const MarkdownExportResult.failure(
        MarkdownExportFailure.biometricDenied,
      );
    }

    Directory? sessionDirectory;
    try {
      final parent = await _temporaryDirectory();
      sessionDirectory = await Directory(
        '${parent.path}/archiveme_markdown_${_nonce()}',
      ).create();
      final exportDirectory = await Directory(
        '${sessionDirectory.path}/export',
      ).create();

      final values = await Future.wait<Object>([
        _loadEntries(),
        _loadManualGraph(),
        _loadActiveHypotheses(),
        _loadSemanticClusters(),
        _loadKnowledgeGraph(),
      ]);
      final entries = values[0] as List<JournalEntry>
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final manualGraph = values[1] as PersonalKnowledgeGraph;
      final hypotheses = values[2] as List<HypothesisEvolution>;
      final clusters = values[3] as List<SemanticCluster>;
      final knowledgeGraph = values[4] as PersonalKnowledgeGraph;

      final entryFiles = <String, String>{};
      for (var index = 0; index < entries.length; index++) {
        entryFiles[entries[index].id] =
            'entries/${_date(entries[index].createdAt)}-'
            '${(index + 1).toString().padLeft(4, '0')}.md';
      }

      await _writeEntryFiles(exportDirectory, entries, entryFiles);
      await _writeText(
        exportDirectory,
        'index.md',
        _indexMarkdown(entries, entryFiles),
      );
      await _writeText(
        exportDirectory,
        'truth-anchors.md',
        _truthAnchorsMarkdown(manualGraph, knowledgeGraph, entries, entryFiles),
      );
      await _writeText(
        exportDirectory,
        'semantic-clusters.md',
        _clustersMarkdown(clusters, manualGraph, knowledgeGraph),
      );
      await _writeText(
        exportDirectory,
        'confidence-history.md',
        _confidenceMarkdown(hypotheses, entries, entryFiles),
      );

      final zipFile = File('${sessionDirectory.path}/archiveme-markdown.zip');
      await zipFile.writeAsBytes(await _zip(exportDirectory), flush: true);
      await _share(zipFile.path);
      return MarkdownExportResult.success(entryCount: entries.length);
    } on Object {
      return const MarkdownExportResult.failure(
        MarkdownExportFailure.exportFailed,
      );
    } finally {
      if (sessionDirectory != null) {
        await _secureDeleteTree(sessionDirectory);
      }
    }
  }

  Future<void> _writeEntryFiles(
    Directory root,
    List<JournalEntry> entries,
    Map<String, String> entryFiles,
  ) async {
    await Directory('${root.path}/entries').create();
    for (final entry in entries) {
      final mediaLinks = <String>[];
      var mediaIndex = 0;
      if (entry.localAudioVaultRef?.isNotEmpty == true) {
        mediaIndex++;
        final relative = 'media/audio-$mediaIndex.m4a';
        final included = await _maybeWriteAttachment(
          root,
          AttachmentExportRequest(
            entryId: entry.id,
            kind: AttachmentExportKind.audio,
            relativePath: relative,
            mimeType: 'audio/mp4',
          ),
        );
        if (included) mediaLinks.add('[Audio recording](../$relative)');
      }
      for (final attachment in entry.mediaAttachments) {
        mediaIndex++;
        final extension = _imageExtension(attachment.mimeType);
        final relative = 'media/image-$mediaIndex.$extension';
        final caption = attachment.caption.isEmpty
            ? 'Image attachment'
            : _inline(attachment.caption);
        final included = await _maybeWriteAttachment(
          root,
          AttachmentExportRequest(
            entryId: entry.id,
            attachmentId: attachment.id,
            kind: AttachmentExportKind.image,
            relativePath: relative,
            mimeType: attachment.mimeType,
          ),
        );
        if (included) mediaLinks.add('![$caption](../$relative)');
      }
      await _writeText(
        root,
        entryFiles[entry.id]!,
        _entryMarkdown(entry, mediaLinks),
      );
    }
  }

  Future<bool> _maybeWriteAttachment(
    Directory root,
    AttachmentExportRequest request,
  ) async {
    final source = attachmentSource;
    if (source == null) return false;
    final bytes = await source.loadAuthorizedPlaintext(request);
    if (bytes == null) return false;
    try {
      final file = File('${root.path}/${request.relativePath}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  String _indexMarkdown(
    List<JournalEntry> entries,
    Map<String, String> entryFiles,
  ) {
    final out = StringBuffer()
      ..write(
        _header({
          'type': 'archive-index',
          'exported_at': _clock().toUtc().toIso8601String(),
          'entry_count': entries.length,
        }),
      )
      ..writeln('# ArchiveMe Markdown export')
      ..writeln()
      ..writeln('This export was created by an explicit user request.')
      ..writeln()
      ..writeln('## Contents')
      ..writeln()
      ..writeln('- [Truth anchors](truth-anchors.md)')
      ..writeln('- [Semantic clusters](semantic-clusters.md)')
      ..writeln('- [Confidence history](confidence-history.md)')
      ..writeln()
      ..writeln('## Journal entries')
      ..writeln();
    for (final entry in entries) {
      out.writeln(
        '- [${_date(entry.createdAt)} — ${_inline(entry.reflectionSummary)}]'
        '(${entryFiles[entry.id]})',
      );
    }
    return out.toString();
  }

  String _entryMarkdown(JournalEntry entry, List<String> mediaLinks) {
    final reflection = entry.reflection;
    final out = StringBuffer()
      ..write(
        _header({
          'type': 'journal-entry',
          'created_at': entry.createdAt.toUtc().toIso8601String(),
          'duration_seconds': entry.durationSeconds,
          'mood': reflection.mood,
          'emotional_intensity': reflection.emotionalIntensity,
          'pinned': entry.isPinned,
          'archived': entry.isArchived,
        }),
      )
      ..writeln('# ${_date(entry.createdAt)} journal entry')
      ..writeln()
      ..writeln('## Transcript')
      ..writeln()
      ..writeln(_block(entry.transcript))
      ..writeln()
      ..writeln('## Reflection summary')
      ..writeln()
      ..writeln(_block(entry.reflectionSummary));
    _section(out, 'Concrete observation', reflection.concreteObservation);
    _section(out, 'Exact language pattern', reflection.exactLanguagePattern);
    _section(out, 'Repeated signal', reflection.repeatedSignal);
    _section(
      out,
      'Tension or contradiction',
      reflection.tensionOrContradiction,
    );
    _section(out, 'Avoided or vague area', reflection.avoidedOrVagueArea);
    _section(out, 'Next small action', reflection.nextSmallAction);
    if (reflection.recurringThemes.isNotEmpty) {
      out
        ..writeln()
        ..writeln('## Recurring themes')
        ..writeln();
      for (final theme in reflection.recurringThemes) {
        out.writeln('- ${_inline(theme)}');
      }
    }
    if (mediaLinks.isNotEmpty) {
      out
        ..writeln()
        ..writeln('## Media')
        ..writeln();
      for (final link in mediaLinks) {
        out.writeln('- $link');
      }
    }
    return out.toString();
  }

  String _truthAnchorsMarkdown(
    PersonalKnowledgeGraph manual,
    PersonalKnowledgeGraph graph,
    List<JournalEntry> entries,
    Map<String, String> entryFiles,
  ) {
    final transcripts = {
      for (final entry in entries) entry.id: entry.transcript,
    };
    final nodes =
        manual.nodes.where((node) => node.origin == NodeOrigin.manual).toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    final edges =
        manual.edges.where((edge) => edge.origin == NodeOrigin.manual).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final labels = {
      for (final node in graph.nodes) node.id: node.label,
      for (final node in manual.nodes) node.id: node.label,
    };
    final out = StringBuffer()
      ..write(
        _header({
          'type': 'truth-anchors',
          'node_count': nodes.length,
          'edge_count': edges.length,
        }),
      )
      ..writeln('# Truth anchors')
      ..writeln();
    if (nodes.isEmpty && edges.isEmpty) {
      return (out..writeln('No manual truth anchors.')).toString();
    }
    for (final node in nodes) {
      out
        ..writeln('## ${_inline(node.label)}')
        ..writeln()
        ..writeln('- Category: `${_inline(node.type.name)}`')
        ..writeln('- Confidence: 100%');
      _writeGraphCitations(out, node.evidence, transcripts, entryFiles);
      out.writeln();
    }
    if (edges.isNotEmpty) {
      out
        ..writeln('## Manual relationships')
        ..writeln();
    }
    for (final edge in edges) {
      final source = labels[edge.sourceNodeId] ?? 'Unknown node';
      final target = labels[edge.targetNodeId] ?? 'Unknown node';
      out.writeln(
        '- **${_inline(source)}** ${_inline(edge.type.name)} '
        '**${_inline(target)}**',
      );
      _writeGraphCitations(out, edge.evidence, transcripts, entryFiles);
    }
    return out.toString();
  }

  String _clustersMarkdown(
    List<SemanticCluster> clusters,
    PersonalKnowledgeGraph manual,
    PersonalKnowledgeGraph graph,
  ) {
    final labels = {
      for (final node in graph.nodes) node.id: node.label,
      for (final node in manual.nodes) node.id: node.label,
    };
    final ordered = clusters.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    final out = StringBuffer()
      ..write(
        _header({'type': 'semantic-clusters', 'cluster_count': ordered.length}),
      )
      ..writeln('# Semantic clusters')
      ..writeln();
    for (final cluster in ordered) {
      out
        ..writeln('## ${_inline(cluster.title)}')
        ..writeln()
        ..writeln('- Category: `${_inline(cluster.category.wireName)}`')
        ..writeln('- Confidence: ${(cluster.confidenceScore * 100).round()}%')
        ..writeln(
          '- Activity velocity: ${(cluster.activityVelocity * 100).round()}%',
        );
      if (cluster.summary.isNotEmpty) {
        out
          ..writeln()
          ..writeln(_block(cluster.summary));
      }
      out
        ..writeln()
        ..writeln('### Nodes')
        ..writeln();
      for (final nodeId in cluster.nodeIds) {
        out.writeln('- ${_inline(labels[nodeId] ?? 'Unavailable node')}');
      }
      out.writeln();
    }
    return out.toString();
  }

  String _confidenceMarkdown(
    List<HypothesisEvolution> hypotheses,
    List<JournalEntry> entries,
    Map<String, String> entryFiles,
  ) {
    final transcripts = {
      for (final entry in entries) entry.id: entry.transcript,
    };
    final ordered = hypotheses.toList()
      ..sort((a, b) => a.statement.compareTo(b.statement));
    final out = StringBuffer()
      ..write(
        _header({
          'type': 'confidence-history',
          'active_hypothesis_count': ordered.length,
        }),
      )
      ..writeln('# Confidence history')
      ..writeln()
      ..writeln(
        'Only citations that exactly match an exported transcript are included.',
      )
      ..writeln();
    for (final hypothesis in ordered) {
      out
        ..writeln('## ${_inline(hypothesis.statement)}')
        ..writeln()
        ..writeln('- Current confidence: ${hypothesis.currentConfidence}%')
        ..writeln()
        ..writeln('### Evolution')
        ..writeln();
      for (final snapshot in hypothesis.evolutionHistory) {
        out
          ..writeln(
            '#### ${_date(snapshot.date)} — ${snapshot.confidenceScore}%',
          )
          ..writeln()
          ..writeln(_block(snapshot.deltaReasoning));
        final citation = snapshot.triggeringEvidence;
        if (_isExactCitation(citation, transcripts)) {
          final file = entryFiles[citation.sourceEntryId];
          out
            ..writeln()
            ..writeln(
              '> “${_block(citation.exactQuote).replaceAll('\n', '\n> ')}”',
            );
          if (file != null) {
            out.writeln('> Source: [exported journal entry]($file)');
          }
        }
        out.writeln();
      }
    }
    return out.toString();
  }

  static void _writeGraphCitations(
    StringBuffer out,
    Iterable<Object> evidence,
    Map<String, String> transcripts,
    Map<String, String> entryFiles,
  ) {
    for (final item in evidence) {
      final entryId = switch (item) {
        GraphNodeEvidence value => value.entryId,
        GraphEdgeEvidence value => value.entryId,
        _ => '',
      };
      final excerpt = switch (item) {
        GraphNodeEvidence value => value.excerpt,
        GraphEdgeEvidence value => value.excerpt,
        _ => '',
      };
      final start = switch (item) {
        GraphNodeEvidence value => value.startUtf16,
        GraphEdgeEvidence value => value.startUtf16,
        _ => -1,
      };
      final end = switch (item) {
        GraphNodeEvidence value => value.endUtf16,
        GraphEdgeEvidence value => value.endUtf16,
        _ => -1,
      };
      final transcript = transcripts[entryId];
      if (transcript == null ||
          start < 0 ||
          end <= start ||
          end > transcript.length ||
          transcript.substring(start, end) != excerpt) {
        continue;
      }
      out
        ..writeln()
        ..writeln('> “${_block(excerpt).replaceAll('\n', '\n> ')}”');
      final file = entryFiles[entryId];
      if (file != null) {
        out.writeln('> Source: [exported journal entry]($file)');
      }
    }
  }

  static bool _isExactCitation(
    VerifiableCitation citation,
    Map<String, String> transcripts,
  ) {
    final transcript = transcripts[citation.sourceEntryId];
    if (transcript == null) return false;
    final start = citation.startUtf16;
    final end = citation.endUtf16;
    if (start != null && end != null) {
      return start >= 0 &&
          end > start &&
          end <= transcript.length &&
          transcript.substring(start, end) == citation.exactQuote;
    }
    return transcript.contains(citation.exactQuote);
  }

  static String _header(Map<String, Object> metadata) {
    final out = StringBuffer('---\n');
    for (final item in metadata.entries) {
      final value = item.value;
      out.writeln(
        '${item.key}: ${value is String ? jsonEncode(_plain(value)) : value}',
      );
    }
    return (out..writeln('---\n')).toString();
  }

  static void _section(StringBuffer out, String title, String? value) {
    if (value?.trim().isEmpty != false) return;
    out
      ..writeln()
      ..writeln('## $title')
      ..writeln()
      ..writeln(_block(value!));
  }

  static String _plain(String value) => value
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  static String _block(String value) {
    var result = _plain(value);
    result = result.replaceAll('&', '&amp;');
    result = result.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    result = result.replaceAll(r'\', r'\\');
    result = result.replaceAllMapped(
      RegExp(r'([`*_{}\[\]#|])'),
      (match) => '\\${match[1]}',
    );
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)([-+>]|[0-9]+\.)\s', multiLine: true),
      (match) => '${match[1]}\\${match[2]} ',
    );
    return result;
  }

  static String _inline(String value) =>
      _block(value).replaceAll('\n', ' ').trim();

  static String _date(DateTime value) =>
      value.toUtc().toIso8601String().split('T').first;

  String _nonce() =>
      '${_clock().toUtc().microsecondsSinceEpoch}_${identityHashCode(this)}';

  static String _imageExtension(String mimeType) => switch (mimeType) {
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    _ => 'jpg',
  };

  static Future<void> _writeText(
    Directory root,
    String relativePath,
    String content,
  ) async {
    if (relativePath.startsWith('/') ||
        relativePath.split('/').contains('..')) {
      throw ArgumentError.value(relativePath, 'relativePath');
    }
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
  }

  static Future<Uint8List> _zip(Directory root) async {
    final archive = Archive();
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = entity.path.substring(root.path.length + 1);
      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static Future<void> _secureDeleteTree(Directory directory) async {
    if (!await directory.exists()) return;
    try {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) await _zeroAndDelete(entity);
      }
      await directory.delete(recursive: true);
    } on Object {
      try {
        await directory.delete(recursive: true);
      } on Object {
        // Best effort after overwrite/delete has already been attempted.
      }
    }
  }

  static Future<void> _zeroAndDelete(File file) async {
    if (!await file.exists()) return;
    RandomAccessFile? handle;
    try {
      final length = await file.length();
      handle = await file.open(mode: FileMode.write);
      final zeros = Uint8List(64 * 1024);
      var remaining = length;
      while (remaining > 0) {
        final count = remaining < zeros.length ? remaining : zeros.length;
        await handle.writeFrom(zeros, 0, count);
        remaining -= count;
      }
      await handle.flush();
    } on Object {
      // Deletion is still preferable if an overwrite is unavailable.
    } finally {
      await handle?.close();
      try {
        await file.delete();
      } on Object {
        // The parent recursive deletion gets one final attempt.
      }
    }
  }

  static Future<void> _shareWithPlatform(String path) => Share.shareXFiles([
    XFile(path, mimeType: 'application/zip'),
  ], subject: 'ArchiveMe Markdown export');
}
