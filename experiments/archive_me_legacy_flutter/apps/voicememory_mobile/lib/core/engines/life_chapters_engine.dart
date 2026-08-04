import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import '../../features/ai_engines/models/ai_explainability.dart';
import 'evidence_reference.dart';

enum LifeChapterCategory {
  university,
  relationship,
  job,
  houseMove,
  illness,
  recovery,
  children,
  business,
  retirement,
}

class LifeChapter {
  LifeChapter({
    required this.category,
    required DateTime startedAt,
    required DateTime endedAt,
    required num confidence,
    required this.earlierDensity,
    required this.laterDensity,
    required Iterable<EvidenceReference> evidence,
  }) : startedAt = startedAt.toUtc(),
       endedAt = endedAt.toUtc(),
       confidence = clampGraphScore(confidence),
       evidence = List.unmodifiable(evidence);

  final LifeChapterCategory category;
  final DateTime startedAt;
  final DateTime endedAt;
  final double confidence;
  final int earlierDensity;
  final int laterDensity;
  final List<EvidenceReference> evidence;

  AiExplainability get explainability => AiExplainability(
    confidence: (confidence * 100).round(),
    evidence: evidence
        .map(
          (item) => AiEvidenceSource(
            sourceId: item.entryId,
            excerpt: item.excerpt,
            startUtf16: item.startUtf16,
            endUtf16: item.endUtf16,
          ),
        )
        .toList(),
    reasoning: [
      'Evidence was ordered across the detected chapter boundary.',
      'Earlier density was $earlierDensity and later density was $laterDensity.',
      'The density change determined the bounded confidence score.',
    ],
    alternativeExplanation:
        'The evidence may describe overlapping events rather than one chapter.',
    uncertainty:
        'Missing recordings can shift the apparent start, end, or category.',
  );
}

class LifeChaptersEngine {
  const LifeChaptersEngine(this.graph);

  final PersonalKnowledgeGraph graph;

  List<LifeChapter> detect({int minimumEvidence = 2}) {
    if (minimumEvidence < 1) {
      throw ArgumentError.value(minimumEvidence, 'minimumEvidence');
    }
    final chapters = <LifeChapter>[];
    for (final entry in _markers.entries) {
      final evidence = _evidenceFor(entry.value);
      if (evidence.length < minimumEvidence) continue;
      final first = evidence.first.observedAt;
      final last = evidence.last.observedAt;
      final midpoint = first.add(last.difference(first) ~/ 2);
      final earlier = evidence
          .where((e) => !e.observedAt.isAfter(midpoint))
          .length;
      final later = evidence.length - earlier;
      final densityShift = (later - earlier).abs() / evidence.length;
      chapters.add(
        LifeChapter(
          category: entry.key,
          startedAt: first,
          endedAt: last,
          confidence: 0.5 + densityShift * 0.5,
          earlierDensity: earlier,
          laterDensity: later,
          evidence: evidence,
        ),
      );
    }
    chapters.sort((a, b) {
      final time = a.startedAt.compareTo(b.startedAt);
      return time != 0 ? time : a.category.index.compareTo(b.category.index);
    });
    return List.unmodifiable(chapters);
  }

  List<EvidenceReference> _evidenceFor(Set<String> markers) {
    final found = <String, EvidenceReference>{};
    for (final node in graph.nodes) {
      final label = normalizeGraphLabel(node.label);
      for (final item in referencesForNode(graph, node)) {
        final text = '$label ${normalizeGraphLabel(item.excerpt)}';
        if (markers.any((marker) => _contains(text, marker))) {
          found[item.entryId] = item;
        }
      }
    }
    final result = found.values.toList()
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
    return result;
  }

  static bool _contains(String text, String marker) =>
      text == marker ||
      text.startsWith('$marker ') ||
      text.endsWith(' $marker') ||
      text.contains(' $marker ');

  static const Map<LifeChapterCategory, Set<String>> _markers = {
    LifeChapterCategory.university: {
      'university',
      'college',
      'degree',
      'campus',
      'graduation',
    },
    LifeChapterCategory.relationship: {
      'relationship',
      'partner',
      'dating',
      'wedding',
      'marriage',
    },
    LifeChapterCategory.job: {'job', 'career', 'work', 'promotion', 'employer'},
    LifeChapterCategory.houseMove: {
      'house move',
      'moving house',
      'new home',
      'relocation',
      'moved',
    },
    LifeChapterCategory.illness: {
      'illness',
      'unwell',
      'sick',
      'hospital',
      'diagnosis',
    },
    LifeChapterCategory.recovery: {
      'recovery',
      'recovering',
      'healing',
      'rehabilitation',
    },
    LifeChapterCategory.children: {
      'children',
      'child',
      'baby',
      'parenthood',
      'parenting',
    },
    LifeChapterCategory.business: {
      'business',
      'company',
      'startup',
      'founder',
      'client',
    },
    LifeChapterCategory.retirement: {'retirement', 'retired', 'pension'},
  };
}
