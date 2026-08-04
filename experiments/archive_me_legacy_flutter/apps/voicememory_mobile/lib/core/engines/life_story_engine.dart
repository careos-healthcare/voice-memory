import '../graph/personal_knowledge_graph.dart';
import 'evidence_reference.dart';
import 'life_chapters_engine.dart';

class LifeStoryChapter {
  LifeStoryChapter({
    required this.category,
    required this.narrative,
    required Iterable<EvidenceReference> evidence,
  }) : evidence = List.unmodifiable(evidence);

  final LifeChapterCategory category;
  final String narrative;
  final List<EvidenceReference> evidence;
}

class LifeStory {
  LifeStory({required Iterable<LifeStoryChapter> chapters})
    : chapters = List.unmodifiable(chapters);

  final List<LifeStoryChapter> chapters;

  bool get isEmpty => chapters.isEmpty;
}

class LifeStoryEngine {
  const LifeStoryEngine(this.graph);

  final PersonalKnowledgeGraph graph;

  LifeStory build({int minimumChapterEvidence = 2}) {
    final chapters = LifeChaptersEngine(
      graph,
    ).detect(minimumEvidence: minimumChapterEvidence);
    return LifeStory(
      chapters: chapters.map(
        (chapter) => LifeStoryChapter(
          category: chapter.category,
          narrative: chapter.evidence
              .map(
                (item) =>
                    '${item.observedAt.toIso8601String()}: ${item.excerpt} '
                    '[${item.entryId}]',
              )
              .join('\n'),
          evidence: chapter.evidence,
        ),
      ),
    );
  }
}
