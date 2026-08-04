import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/engines/life_story_engine.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../models/journal_entry.dart';
import '../../security/app_lock_service.dart';
import '../../services/app_services.dart';
import '../../services/life_os_graph_builder.dart';

enum LifeOsExportKind { autobiography, knowledgeGraph }

class LifeOsExportArtifact {
  const LifeOsExportArtifact({
    required this.contents,
    required this.filename,
    required this.mimeType,
    required this.kind,
  });

  final String contents;
  final String filename;
  final String mimeType;
  final LifeOsExportKind kind;
}

/// A deliberately detail-free error suitable for crossing into UI code.
class LifeOsExportAuthorizationException implements Exception {
  const LifeOsExportAuthorizationException();

  @override
  String toString() => 'Life OS export is not authorized.';
}

abstract interface class LifeOsExportAuthorization {
  Future<void> authorize();
}

class ForegroundUnlockedLifeOsExportAuthorization
    implements LifeOsExportAuthorization {
  ForegroundUnlockedLifeOsExportAuthorization({
    Future<bool> Function()? isLocked,
    AppLifecycleState? Function()? lifecycleState,
  }) : _isLocked = isLocked ?? AppLockService.instance.isLocked,
       _lifecycleState =
           lifecycleState ?? (() => WidgetsBinding.instance.lifecycleState);

  final Future<bool> Function() _isLocked;
  final AppLifecycleState? Function() _lifecycleState;

  @override
  Future<void> authorize() async {
    if (_lifecycleState() != AppLifecycleState.resumed || await _isLocked()) {
      throw const LifeOsExportAuthorizationException();
    }
  }
}

typedef LifeOsGraphBuilder =
    PersonalKnowledgeGraph Function(Iterable<JournalEntry> entries);

class PersonalLifeOsExportService {
  PersonalLifeOsExportService({
    LifeOsExportAuthorization? authorization,
    LifeOsGraphBuilder? graphBuilder,
    AsyncLifeOsGraphBuilder? asyncGraphBuilder,
  }) : _authorization =
           authorization ?? ForegroundUnlockedLifeOsExportAuthorization(),
       _graphBuilder = graphBuilder ?? PersonalKnowledgeGraphEngine().rebuild,
       _asyncGraphBuilder =
           asyncGraphBuilder ??
           (graphBuilder == null && AppServices.isInitialized
               ? buildProductionLifeOsGraph
               : null);

  final LifeOsExportAuthorization _authorization;
  final LifeOsGraphBuilder _graphBuilder;
  final AsyncLifeOsGraphBuilder? _asyncGraphBuilder;

  /// Call immediately before each operation that exposes an artifact.
  Future<void> reauthorize() => _authorization.authorize();

  Future<LifeOsExportArtifact> buildAutobiography(
    Iterable<JournalEntry> entries, {
    required DateTime exportedAt,
  }) async {
    await reauthorize();
    final graph = await _buildGraph(entries);
    final story = LifeStoryEngine(graph).build();
    final utc = exportedAt.toUtc();
    final chapters = story.chapters.toList()
      ..sort((a, b) {
        final aDate = a.evidence.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
            : a.evidence
                  .map((item) => item.observedAt)
                  .reduce((left, right) => left.isBefore(right) ? left : right);
        final bDate = b.evidence.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
            : b.evidence
                  .map((item) => item.observedAt)
                  .reduce((left, right) => left.isBefore(right) ? left : right);
        final byDate = aDate.compareTo(bDate);
        return byDate != 0
            ? byDate
            : a.category.index.compareTo(b.category.index);
      });

    final output = StringBuffer()
      ..writeln('# ArchiveMe Life Story')
      ..writeln()
      ..writeln('Generated (UTC): ${_date(utc)}')
      ..writeln('Chapter count: ${chapters.length}')
      ..writeln();
    if (chapters.isEmpty) {
      output
        ..writeln('## Your story is still taking shape')
        ..writeln()
        ..writeln('No life-story chapters have enough evidence to include yet.')
        ..writeln();
    } else {
      for (final chapter in chapters) {
        output
          ..writeln('## ${_chapterTitle(chapter.category.name)}')
          ..writeln()
          ..writeln('### Evidence-backed narrative')
          ..writeln();
        final evidence = chapter.evidence.toList()
          ..sort((a, b) {
            final byDate = a.observedAt.compareTo(b.observedAt);
            return byDate != 0 ? byDate : a.entryId.compareTo(b.entryId);
          });
        for (final item in evidence) {
          output.writeln(
            '- ${_escapeMarkdown(_cappedExcerpt(item.excerpt))} '
            '[entryId: ${_escapeMarkdown(item.entryId)}; '
            'observedAt: ${item.observedAt.toUtc().toIso8601String()}; '
            'confidence: ${item.confidence}]',
          );
        }
        output.writeln();
      }
    }
    output
      ..writeln('---')
      ..writeln(
        'Review before sharing. This export contains private ArchiveMe '
        'evidence and should only be shared with people you trust.',
      );

    return LifeOsExportArtifact(
      contents: output.toString(),
      filename: 'archiveme-life-story-${_date(utc)}.md',
      mimeType: 'text/markdown',
      kind: LifeOsExportKind.autobiography,
    );
  }

  Future<LifeOsExportArtifact> buildKnowledgeGraphPackage(
    Iterable<JournalEntry> entries, {
    required DateTime exportedAt,
  }) async {
    await reauthorize();
    final graph = await _buildGraph(entries);
    final envelope = <String, dynamic>{
      'product': 'ArchiveMe',
      'format': 'personal-life-os-knowledge-graph',
      'version': 1,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'graph': _portableGraph(graph),
    };
    final utc = exportedAt.toUtc();
    return LifeOsExportArtifact(
      contents: const JsonEncoder.withIndent('  ').convert(envelope),
      filename: 'archiveme-knowledge-graph-${_date(utc)}.json',
      mimeType: 'application/json',
      kind: LifeOsExportKind.knowledgeGraph,
    );
  }

  static Map<String, dynamic> _portableGraph(PersonalKnowledgeGraph graph) {
    final nodes = graph.nodes.toList()..sort((a, b) => a.id.compareTo(b.id));
    final edges = graph.edges.toList()..sort((a, b) => a.id.compareTo(b.id));
    return {
      'schemaVersion': graph.schemaVersion,
      'nodes': nodes.map((node) {
        final evidence = node.evidence.toList()
          ..sort((a, b) {
            final byDate = a.observedAt.compareTo(b.observedAt);
            return byDate != 0 ? byDate : a.entryId.compareTo(b.entryId);
          });
        return {
          'id': node.id,
          'type': node.type.name,
          'label': node.label,
          'confidence': node.confidence,
          'evidence': evidence
              .map(
                (item) => {
                  'entryId': item.entryId,
                  'observedAt': item.observedAt.toUtc().toIso8601String(),
                  'confidence': item.confidence,
                  'excerpt': _cappedExcerpt(item.excerpt),
                },
              )
              .toList(),
        };
      }).toList(),
      'edges': edges.map((edge) {
        final evidence = edge.evidence.toList()
          ..sort((a, b) {
            final byDate = a.observedAt.compareTo(b.observedAt);
            return byDate != 0 ? byDate : a.entryId.compareTo(b.entryId);
          });
        return {
          'id': edge.id,
          'sourceNodeId': edge.sourceNodeId,
          'targetNodeId': edge.targetNodeId,
          'type': edge.type.name,
          'isDirected': edge.isDirected,
          'weight': edge.weight,
          'evidence': evidence
              .map(
                (item) => {
                  'entryId': item.entryId,
                  'observedAt': item.observedAt.toUtc().toIso8601String(),
                  'confidence': item.confidence,
                  'excerpt': _cappedExcerpt(item.excerpt),
                },
              )
              .toList(),
        };
      }).toList(),
    };
  }

  Future<PersonalKnowledgeGraph> _buildGraph(
    Iterable<JournalEntry> entries,
  ) async {
    final asyncBuilder = _asyncGraphBuilder;
    return asyncBuilder == null
        ? _graphBuilder(entries)
        : asyncBuilder(entries);
  }

  static String _date(DateTime value) =>
      value.toIso8601String().split('T').first;

  static String _cappedExcerpt(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return compact.length <= 160 ? compact : '${compact.substring(0, 159)}…';
  }

  static String _escapeMarkdown(String value) => value.replaceAllMapped(
    RegExp(r'[\\`*_{}\[\]<>()#+\-.!|]'),
    (match) => '\\${match.group(0)}',
  );

  static String _chapterTitle(String name) {
    final spaced = name.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}
