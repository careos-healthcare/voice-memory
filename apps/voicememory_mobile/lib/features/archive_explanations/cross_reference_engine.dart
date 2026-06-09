import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_state_object/archive_state_object.dart';
import '../belief_shift/belief_shift_engine.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import '../discover/blind_spot_engine.dart';
import '../discover/theme_engine.dart';
import 'explanation_models.dart';

/// Graph-style relationships between archive insight types.
class CrossReferenceEngine {
  const CrossReferenceEngine();

  static const int minScore = 40;

  CrossReferenceResult build({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    String? focusBelief,
    List<String> focusThemeKeys = const [],
    List<String> focusEntryIds = const [],
  }) {
    if (!archiveHasMinimumEvidence(entries)) {
      return CrossReferenceResult.empty;
    }

    final belief = focusBelief?.trim() ?? state?.belief?.trim() ?? '';
    final themes = DiscoverThemeEngine().build(entries: entries);
    final blindSpots = const DiscoverBlindSpotEngine().build(entries);
    final contradictions = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: belief.isNotEmpty ? belief : null,
    );
    final shifts = const BeliefShiftEngine().detect(
      entries: entries,
      currentBelief: belief.isNotEmpty ? belief : null,
    );

    final relatedThemes = <RelatedTheme>[];
    for (final t in themes) {
      var score = 50 + t.frequency * 4;
      if (focusThemeKeys.contains(t.themeKey)) score += 25;
      if (belief.isNotEmpty &&
          belief.toLowerCase().contains(t.themeKey)) {
        score += 15;
      }
      if (score >= minScore) {
        relatedThemes.add(
          RelatedTheme(
            name: t.name,
            themeKey: t.themeKey,
            frequency: t.frequency,
            relevanceScore: score.clamp(0, 100),
          ),
        );
      }
    }
    relatedThemes.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    final relatedBeliefs = <RelatedBelief>[];
    if (belief.isNotEmpty) {
      relatedBeliefs.add(
        RelatedBelief(statement: belief, relevanceScore: 95),
      );
    }
    for (final s in shifts.reports.take(3)) {
      if (s.newBelief.toLowerCase() == belief.toLowerCase()) continue;
      relatedBeliefs.add(
        RelatedBelief(
          statement: s.newBelief,
          relevanceScore: s.confidence,
        ),
      );
    }

    final relatedBlindSpots = <RelatedBlindSpot>[];
    for (final b in blindSpots) {
      var score = 55 + b.confidence ~/ 2;
      if (focusEntryIds.any(b.entryIds.contains)) score += 20;
      relatedBlindSpots.add(
        RelatedBlindSpot(
          id: b.id,
          headline: b.headline,
          relevanceScore: score.clamp(0, 100),
        ),
      );
    }
    relatedBlindSpots.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    final relatedContradictions = <RelatedContradiction>[];
    for (final c in contradictions.reports) {
      var score = c.confidenceScore;
      if (focusEntryIds.contains(c.originalEntryId) ||
          focusEntryIds.contains(c.conflictingEntryId)) {
        score += 15;
      }
      relatedContradictions.add(
        RelatedContradiction(
          id: c.id,
          summary:
              '“${c.originalStatement}” vs “${c.conflictingStatement}”',
          relevanceScore: score.clamp(0, 100),
        ),
      );
    }

    return CrossReferenceResult(
      relatedThemes: relatedThemes.take(6).toList(),
      relatedBeliefs: relatedBeliefs.take(4).toList(),
      relatedBlindSpots: relatedBlindSpots.take(4).toList(),
      relatedContradictions: relatedContradictions.take(4).toList(),
    );
  }
}

class CrossReferenceResult {
  const CrossReferenceResult({
    required this.relatedThemes,
    required this.relatedBeliefs,
    required this.relatedBlindSpots,
    required this.relatedContradictions,
  });

  final List<RelatedTheme> relatedThemes;
  final List<RelatedBelief> relatedBeliefs;
  final List<RelatedBlindSpot> relatedBlindSpots;
  final List<RelatedContradiction> relatedContradictions;

  static const empty = CrossReferenceResult(
    relatedThemes: [],
    relatedBeliefs: [],
    relatedBlindSpots: [],
    relatedContradictions: [],
  );
}
