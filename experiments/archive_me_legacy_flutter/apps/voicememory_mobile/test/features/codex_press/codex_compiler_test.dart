import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/codex_press/codex_compiler.dart';
import 'package:voicememory_mobile/features/codex_press/codex_models.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  final first = _entry('a', DateTime.utc(2020), 'A true beginning.');
  final duplicate = _entry(
    'b',
    DateTime.utc(2020, 1, 2),
    '  A TRUE beginning. ',
  );
  final later = _entry('c', DateTime.utc(2021), 'A later chapter.');

  CodexCompiler compiler({
    List<JournalEntry>? journals,
    List<SemanticCluster> clusters = const [],
  }) => CodexCompiler.loaders(
    graphLoader: () async => PersonalKnowledgeGraph(),
    clusterLoader: () async => clusters,
    journalLoader: () async => journals ?? [first, duplicate, later],
    audioLoader: () async => [],
    transcriptLoader: (_) async => null,
    clock: () => DateTime.utc(2026),
  );

  test('chronological compilation is deterministic and deduplicated', () async {
    final request = const CodexCompilationRequest(
      title: 'Local Memoir',
      template: CodexPublicationTemplate.minimalistJournal,
      organization: CodexOrganization.chronological,
    );
    final one = await compiler().compile(request);
    final two = await compiler().compile(request);

    expect(one.toJson(), two.toJson());
    expect(one.chapters, hasLength(2));
    expect(one.chapters.expand((chapter) => chapter.passages), hasLength(2));
    expect(
      one.chapters.first.passages.first.citations.single.sourceId,
      first.id,
    );
  });

  test('thematic compilation respects selected manual order', () async {
    final alpha = _cluster('alpha', 'Alpha');
    final beta = _cluster('beta', 'Beta');
    final result = await compiler(journals: const [], clusters: [alpha, beta])
        .compile(
          const CodexCompilationRequest(
            title: 'Themes',
            template: CodexPublicationTemplate.academicMonograph,
            organization: CodexOrganization.thematic,
            selectedClusterIds: ['alpha', 'beta'],
            chapterOrder: ['beta', 'alpha'],
            includeUnclustered: false,
          ),
        );

    expect(result.chapters.map((chapter) => chapter.title), ['Beta', 'Alpha']);
    expect(
      result.chapters.every(
        (chapter) => chapter.passages.single.citations.isNotEmpty,
      ),
      isTrue,
    );
  });

  test('source selection excludes unselected memories', () async {
    final result = await compiler().compile(
      const CodexCompilationRequest(
        title: 'Selected',
        template: CodexPublicationTemplate.minimalistJournal,
        organization: CodexOrganization.chronological,
        selectedSourceIds: ['c'],
      ),
    );
    expect(result.chapters, hasLength(1));
    expect(result.chapters.single.passages.single.text, 'A later chapter.');
  });

  test('cancellation stops compilation', () async {
    final cancellation = CodexCancellation()..cancel();
    expect(
      () => compiler().compile(
        const CodexCompilationRequest(
          title: 'Cancelled',
          template: CodexPublicationTemplate.cinematicMemoir,
          organization: CodexOrganization.chronological,
        ),
        cancellation: cancellation,
      ),
      throwsA(isA<CodexCancelledException>()),
    );
  });
}

JournalEntry _entry(String id, DateTime date, String text) => JournalEntry(
  id: id,
  createdAt: date,
  transcript: text,
  durationSeconds: 1,
  reflection: const Reflection(
    mood: '',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

SemanticCluster _cluster(String id, String title) => SemanticCluster(
  id: id,
  title: title,
  category: SemanticClusterCategory.theme,
  nodeIds: ['$id-node'],
  activityVelocity: 0,
  confidenceScore: 1,
  summary: '$title is supported by a local semantic cluster.',
  updatedAt: DateTime.utc(2024),
);
