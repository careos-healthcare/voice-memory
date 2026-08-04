import 'dart:math';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../semantic_clusters/semantic_cluster.dart';
import '../semantic_clusters/semantic_cluster_store.dart';
import '../whispering_vault/audio_vault_storage.dart';
import 'codex_models.dart';

typedef CodexGraphLoader = Future<PersonalKnowledgeGraph> Function();
typedef CodexClusterLoader = Future<List<SemanticCluster>> Function();
typedef CodexJournalLoader = Future<List<JournalEntry>> Function();
typedef CodexAudioLoader = Future<List<AudioVaultRecord>> Function();
typedef CodexTranscriptLoader = Future<String?> Function(String id);

final class CodexCompiler {
  factory CodexCompiler({
    required PersonalKnowledgeGraphStore graphStore,
    required SemanticClusterStore clusterStore,
    required JournalStore journalStore,
    required AudioVaultStorage audioVault,
    DateTime Function()? clock,
  }) => CodexCompiler.loaders(
    graphLoader: graphStore.load,
    clusterLoader: clusterStore.list,
    journalLoader: journalStore.loadAll,
    audioLoader: audioVault.list,
    transcriptLoader: audioVault.transcript,
    clock: clock,
  );

  factory CodexCompiler.loaders({
    required CodexGraphLoader graphLoader,
    required CodexClusterLoader clusterLoader,
    required CodexJournalLoader journalLoader,
    required CodexAudioLoader audioLoader,
    required CodexTranscriptLoader transcriptLoader,
    DateTime Function()? clock,
  }) => CodexCompiler._(
    graphLoader,
    clusterLoader,
    journalLoader,
    audioLoader,
    transcriptLoader,
    clock ?? DateTime.now,
  );

  CodexCompiler._(
    this._graphLoader,
    this._clusterLoader,
    this._journalLoader,
    this._audioLoader,
    this._transcriptLoader,
    this._clock,
  );

  static const maximumSources = 500;
  static const maximumSourceCharacters = 100000;
  static const maximumManuscriptCharacters = 2000000;
  static const maximumChapters = 64;

  final CodexGraphLoader _graphLoader;
  final CodexClusterLoader _clusterLoader;
  final CodexJournalLoader _journalLoader;
  final CodexAudioLoader _audioLoader;
  final CodexTranscriptLoader _transcriptLoader;
  final DateTime Function() _clock;

  Future<List<CodexSourceOption>> listSourceOptions() async {
    final values = await Future.wait<Object>([
      _journalLoader(),
      _audioLoader(),
    ]);
    final journals = [...values[0] as List<JournalEntry>]..sort(_journalOrder);
    final audio = [...values[1] as List<AudioVaultRecord>]
      ..sort((a, b) {
        final time = a.capturedAt.compareTo(b.capturedAt);
        return time != 0 ? time : a.id.compareTo(b.id);
      });
    return [
      ...journals.map(
        (entry) => CodexSourceOption(
          id: entry.id,
          kind: CodexSourceKind.journal,
          occurredAt: entry.createdAt,
          label: entry.reflectionSummary.isEmpty
              ? _datedHeading('Journal', entry.createdAt)
              : entry.reflectionSummary,
        ),
      ),
      ...audio
          .where((item) => item.hasTranscript)
          .map(
            (record) => CodexSourceOption(
              id: record.id,
              kind: CodexSourceKind.audioTranscript,
              occurredAt: record.capturedAt,
              label: _datedHeading('Voice memory', record.capturedAt),
            ),
          ),
    ].take(maximumSources).toList(growable: false);
  }

  Future<CodexManuscript> compile(
    CodexCompilationRequest request, {
    CodexCancellation? cancellation,
  }) async {
    final title = request.title.trim();
    if (title.isEmpty || title.length > 160) {
      throw const FormatException('Codex title is invalid.');
    }
    final token = cancellation ?? CodexCancellation();
    final values = await Future.wait<Object>([
      _graphLoader(),
      _clusterLoader(),
      _journalLoader(),
      _audioLoader(),
    ]);
    token.throwIfCancelled();
    final graph = values[0] as PersonalKnowledgeGraph;
    final clusters = values[1] as List<SemanticCluster>;
    final journals = values[2] as List<JournalEntry>;
    final audio = values[3] as List<AudioVaultRecord>;
    final nodeIdsBySource = <String, Set<String>>{};
    for (final node in graph.nodes) {
      for (final evidence in node.evidence) {
        nodeIdsBySource.putIfAbsent(evidence.entryId, () => {}).add(node.id);
      }
    }
    final sources = <_CodexSource>[];
    final seenText = <String>{};
    final orderedJournals = [...journals]..sort(_journalOrder);
    for (final entry in orderedJournals) {
      token.throwIfCancelled();
      _addSource(
        sources,
        seenText,
        _CodexSource(
          id: entry.id,
          kind: CodexSourceKind.journal,
          occurredAt: entry.createdAt,
          heading: entry.reflectionSummary.isEmpty
              ? _datedHeading('Journal', entry.createdAt)
              : entry.reflectionSummary,
          text: entry.transcript,
          nodeIds: nodeIdsBySource[entry.id] ?? const {},
        ),
      );
    }
    final orderedAudio = [...audio]
      ..sort((a, b) {
        final time = a.capturedAt.compareTo(b.capturedAt);
        return time != 0 ? time : a.id.compareTo(b.id);
      });
    for (final record in orderedAudio.where((item) => item.hasTranscript)) {
      token.throwIfCancelled();
      final transcript = await _transcriptLoader(record.id);
      if (transcript == null) continue;
      _addSource(
        sources,
        seenText,
        _CodexSource(
          id: record.id,
          kind: CodexSourceKind.audioTranscript,
          occurredAt: record.capturedAt,
          heading: _datedHeading('Voice memory', record.capturedAt),
          text: transcript,
          nodeIds: nodeIdsBySource[record.id] ?? const {},
        ),
      );
    }
    token.throwIfCancelled();
    final selectedIds = request.selectedClusterIds.toSet();
    final selectedSourceIds = request.selectedSourceIds.toSet();
    final selectedClusters =
        clusters
            .where(
              (cluster) =>
                  selectedIds.isEmpty || selectedIds.contains(cluster.id),
            )
            .toList()
          ..sort(_clusterOrder(request.chapterOrder));
    final selectedNodeIds = selectedClusters
        .expand((cluster) => cluster.nodeIds)
        .toSet();
    final sourceFiltered = selectedSourceIds.isEmpty
        ? sources
        : sources
              .where((source) => selectedSourceIds.contains(source.id))
              .toList();
    final filtered = selectedIds.isEmpty
        ? sourceFiltered
        : sourceFiltered
              .where(
                (source) =>
                    source.nodeIds.any(selectedNodeIds.contains) ||
                    (request.includeUnclustered && source.nodeIds.isEmpty),
              )
              .toList();
    final chapters = request.organization == CodexOrganization.chronological
        ? _chronological(filtered, selectedClusters)
        : _thematic(
            filtered,
            selectedClusters,
            graph,
            includeUnclustered: request.includeUnclustered,
          );
    if (chapters.length > maximumChapters) {
      throw const FormatException('Codex exceeds the chapter limit.');
    }
    final characters = chapters
        .expand((chapter) => chapter.passages)
        .fold<int>(0, (sum, passage) => sum + passage.text.length);
    if (characters > maximumManuscriptCharacters) {
      throw const FormatException('Codex exceeds the manuscript size limit.');
    }
    return CodexManuscript(
      id: stableGraphId('codex', [
        title,
        request.organization.name,
        ...chapters.map((chapter) => chapter.id),
      ]),
      title: title,
      template: request.template,
      organization: request.organization,
      generatedAt: _clock(),
      chapters: chapters,
    );
  }

  List<CodexChapter> _chronological(
    List<_CodexSource> sources,
    List<SemanticCluster> clusters,
  ) {
    final sorted = [...sources]..sort(_sourceOrder);
    if (sorted.isEmpty) return const [];
    final groups = <List<_CodexSource>>[];
    var current = <_CodexSource>[];
    for (final source in sorted) {
      final previous = current.lastOrNull;
      final gap = previous == null
          ? Duration.zero
          : source.occurredAt.difference(previous.occurredAt);
      if (current.isNotEmpty &&
          (gap >= const Duration(days: 120) || current.length >= 12)) {
        groups.add(current);
        current = [];
      }
      current.add(source);
    }
    if (current.isNotEmpty) groups.add(current);
    return [
      for (var index = 0; index < groups.length; index++)
        _chapterFromSources(
          id: 'chronological-${index + 1}',
          title: _rangeTitle(groups[index].first, groups[index].last),
          ordinal: index,
          sources: groups[index],
          clusterIds: clusters
              .where(
                (cluster) => groups[index].any(
                  (source) => source.nodeIds.any(cluster.nodeIds.contains),
                ),
              )
              .map((cluster) => cluster.id),
        ),
    ];
  }

  List<CodexChapter> _thematic(
    List<_CodexSource> sources,
    List<SemanticCluster> clusters,
    PersonalKnowledgeGraph graph, {
    required bool includeUnclustered,
  }) {
    final chapters = <CodexChapter>[];
    final includedSourceIds = <String>{};
    final nodeById = {for (final node in graph.nodes) node.id: node};
    for (final cluster in clusters) {
      final clusterNodes = cluster.nodeIds.toSet();
      final matching =
          sources
              .where((source) => source.nodeIds.any(clusterNodes.contains))
              .toList()
            ..sort(_sourceOrder);
      includedSourceIds.addAll(matching.map((item) => item.id));
      final passages = [
        if (cluster.summary.trim().isNotEmpty)
          CodexPassage(
            heading: 'Theme overview',
            text: cluster.summary,
            citations: [
              CodexCitation(
                sourceId: cluster.id,
                kind: CodexSourceKind.semanticCluster,
                occurredAt: cluster.updatedAt,
                label: cluster.title,
              ),
            ],
          ),
        ...matching.map(_passage),
        if (matching.isEmpty && cluster.summary.trim().isEmpty)
          CodexPassage(
            heading: 'Graph constellation',
            text: cluster.nodeIds
                .map((id) => nodeById[id]?.label)
                .whereType<String>()
                .take(30)
                .join(' · '),
            citations: [
              CodexCitation(
                sourceId: cluster.id,
                kind: CodexSourceKind.semanticCluster,
                occurredAt: cluster.updatedAt,
                label: cluster.title,
              ),
            ],
          ),
      ];
      if (passages.every((passage) => passage.text.isEmpty)) continue;
      final dates = matching.map((item) => item.occurredAt).toList()..sort();
      chapters.add(
        CodexChapter(
          id: 'theme-${cluster.id}',
          title: cluster.title,
          ordinal: chapters.length,
          start: dates.firstOrNull ?? cluster.updatedAt,
          end: dates.lastOrNull ?? cluster.updatedAt,
          passages: passages,
          clusterIds: [cluster.id],
        ),
      );
    }
    if (includeUnclustered) {
      final unclustered =
          sources
              .where((source) => !includedSourceIds.contains(source.id))
              .toList()
            ..sort(_sourceOrder);
      if (unclustered.isNotEmpty) {
        chapters.add(
          _chapterFromSources(
            id: 'unclustered-appendix',
            title: 'Appendix: Unclustered Memories',
            ordinal: chapters.length,
            sources: unclustered,
            clusterIds: const [],
          ),
        );
      }
    }
    return chapters;
  }

  CodexChapter _chapterFromSources({
    required String id,
    required String title,
    required int ordinal,
    required List<_CodexSource> sources,
    required Iterable<String> clusterIds,
  }) => CodexChapter(
    id: id,
    title: title,
    ordinal: ordinal,
    start: sources.first.occurredAt,
    end: sources.last.occurredAt,
    passages: sources.map(_passage),
    clusterIds: clusterIds,
  );

  CodexPassage _passage(_CodexSource source) => CodexPassage(
    heading: source.heading,
    text: source.text,
    citations: [
      CodexCitation(
        sourceId: source.id,
        kind: source.kind,
        occurredAt: source.occurredAt,
        label: source.heading,
      ),
    ],
  );

  void _addSource(
    List<_CodexSource> target,
    Set<String> seen,
    _CodexSource source,
  ) {
    if (target.length >= maximumSources) return;
    final text = source.text.trim();
    if (text.isEmpty || text.length > maximumSourceCharacters) return;
    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!seen.add(normalized)) return;
    target.add(source.copyWith(text: text));
  }

  static int _journalOrder(JournalEntry a, JournalEntry b) {
    final time = a.createdAt.compareTo(b.createdAt);
    return time != 0 ? time : a.id.compareTo(b.id);
  }

  static int _sourceOrder(_CodexSource a, _CodexSource b) {
    final time = a.occurredAt.compareTo(b.occurredAt);
    return time != 0 ? time : a.id.compareTo(b.id);
  }

  static int Function(SemanticCluster, SemanticCluster) _clusterOrder(
    List<String> manualOrder,
  ) {
    final manual = {
      for (var index = 0; index < manualOrder.length; index++)
        manualOrder[index]: index,
    };
    return (a, b) {
      final aManual = manual[a.id];
      final bManual = manual[b.id];
      if (aManual != null || bManual != null) {
        return (aManual ?? 1 << 30).compareTo(bManual ?? 1 << 30);
      }
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final category = a.category.index.compareTo(b.category.index);
      if (category != 0) return category;
      final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return title != 0 ? title : a.id.compareTo(b.id);
    };
  }

  static String _datedHeading(String prefix, DateTime date) =>
      '$prefix — ${date.toUtc().toIso8601String().substring(0, 10)}';

  static String _rangeTitle(_CodexSource first, _CodexSource last) {
    final start = first.occurredAt.toUtc();
    final end = last.occurredAt.toUtc();
    if (start.year == end.year) return 'Chapter of ${start.year}';
    return '${start.year}–${end.year}';
  }
}

final class _CodexSource {
  const _CodexSource({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.heading,
    required this.text,
    required this.nodeIds,
  });

  final String id;
  final CodexSourceKind kind;
  final DateTime occurredAt;
  final String heading;
  final String text;
  final Set<String> nodeIds;

  _CodexSource copyWith({String? text}) => _CodexSource(
    id: id,
    kind: kind,
    occurredAt: occurredAt,
    heading: heading.substring(0, min(heading.length, 200)),
    text: text ?? this.text,
    nodeIds: nodeIds,
  );
}
