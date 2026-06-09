/// Kind of insight that can be explained.
enum ArchiveInsightKind {
  belief,
  beliefChange,
  theme,
  contradiction,
  blindSpot,
  chapter,
  weeklyStory,
  askArchive,
  surprise,
  challenge,
}

/// Reference passed to routes and the explanation engine.
class ArchiveInsightRef {
  const ArchiveInsightRef({
    required this.id,
    required this.kind,
    this.index,
    this.themeKey,
    this.chapterId,
    this.blindSpotId,
    this.entryIdA,
    this.entryIdB,
    this.askPrompt,
    this.surpriseIndex,
    this.challengeIndex,
  });

  final String id;
  final ArchiveInsightKind kind;
  final int? index;
  final String? themeKey;
  final String? chapterId;
  final String? blindSpotId;
  final String? entryIdA;
  final String? entryIdB;
  final String? askPrompt;
  final int? surpriseIndex;
  final int? challengeIndex;

  static ArchiveInsightRef belief() =>
      const ArchiveInsightRef(id: 'belief', kind: ArchiveInsightKind.belief);

  static ArchiveInsightRef beliefChange(int index) => ArchiveInsightRef(
        id: 'belief-change:$index',
        kind: ArchiveInsightKind.beliefChange,
        index: index,
      );

  static ArchiveInsightRef theme(String key) => ArchiveInsightRef(
        id: 'theme:$key',
        kind: ArchiveInsightKind.theme,
        themeKey: key,
      );

  static ArchiveInsightRef contradiction({
    required String entryIdA,
    required String entryIdB,
  }) =>
      ArchiveInsightRef(
        id: 'contradiction:$entryIdA|$entryIdB',
        kind: ArchiveInsightKind.contradiction,
        entryIdA: entryIdA,
        entryIdB: entryIdB,
      );

  static ArchiveInsightRef blindSpot(String spotId) => ArchiveInsightRef(
        id: 'blindspot:$spotId',
        kind: ArchiveInsightKind.blindSpot,
        blindSpotId: spotId,
      );

  static ArchiveInsightRef chapter(String chapterId) => ArchiveInsightRef(
        id: 'chapter:$chapterId',
        kind: ArchiveInsightKind.chapter,
        chapterId: chapterId,
      );

  static ArchiveInsightRef weeklyStory() => const ArchiveInsightRef(
        id: 'weekly-story',
        kind: ArchiveInsightKind.weeklyStory,
      );

  static ArchiveInsightRef askArchive(String prompt) => ArchiveInsightRef(
        id: 'ask:${prompt.hashCode}',
        kind: ArchiveInsightKind.askArchive,
        askPrompt: prompt,
      );

  static ArchiveInsightRef surprise(int index) => ArchiveInsightRef(
        id: 'surprise:$index',
        kind: ArchiveInsightKind.surprise,
        surpriseIndex: index,
      );

  static ArchiveInsightRef challenge(int index) => ArchiveInsightRef(
        id: 'challenge:$index',
        kind: ArchiveInsightKind.challenge,
        challengeIndex: index,
      );

  static ArchiveInsightRef? parseRouteId(String routeId) {
    if (routeId.isEmpty) return null;
    if (routeId == 'belief') return belief();
    if (routeId == 'weekly-story') return weeklyStory();
    if (routeId.startsWith('belief-change:')) {
      final i = int.tryParse(routeId.split(':').last);
      if (i != null) return beliefChange(i);
    }
    if (routeId.startsWith('theme:')) {
      return theme(routeId.substring(6));
    }
    if (routeId.startsWith('blindspot:')) {
      return blindSpot(routeId.substring(10));
    }
    if (routeId.startsWith('chapter:')) {
      return chapter(routeId.substring(8));
    }
    if (routeId.startsWith('contradiction:')) {
      final parts = routeId.substring(14).split('|');
      if (parts.length == 2) {
        return contradiction(entryIdA: parts[0], entryIdB: parts[1]);
      }
    }
    if (routeId.startsWith('ask:')) {
      return ArchiveInsightRef(
        id: routeId,
        kind: ArchiveInsightKind.askArchive,
      );
    }
    if (routeId.startsWith('surprise:')) {
      final i = int.tryParse(routeId.split(':').last);
      if (i != null) return surprise(i);
    }
    if (routeId.startsWith('challenge:')) {
      final i = int.tryParse(routeId.split(':').last);
      if (i != null) return challenge(i);
    }
    return null;
  }
}

class EvidenceReference {
  const EvidenceReference({
    required this.entryId,
    required this.recordedAt,
    required this.excerpt,
  });

  final String entryId;
  final DateTime recordedAt;
  final String excerpt;
}

class RelatedTheme {
  const RelatedTheme({
    required this.name,
    required this.themeKey,
    required this.frequency,
    required this.relevanceScore,
  });

  final String name;
  final String themeKey;
  final int frequency;
  final int relevanceScore;
}

class RelatedBelief {
  const RelatedBelief({
    required this.statement,
    required this.relevanceScore,
  });

  final String statement;
  final int relevanceScore;
}

class RelatedBlindSpot {
  const RelatedBlindSpot({
    required this.id,
    required this.headline,
    required this.relevanceScore,
  });

  final String id;
  final String headline;
  final int relevanceScore;
}

class RelatedContradiction {
  const RelatedContradiction({
    required this.id,
    required this.summary,
    required this.relevanceScore,
  });

  final String id;
  final String summary;
  final int relevanceScore;
}

class BeliefTimelinePoint {
  const BeliefTimelinePoint({
    required this.label,
    required this.year,
    required this.month,
    required this.strengthPercent,
  });

  final String label;
  final int year;
  final int month;
  final int strengthPercent;
}

enum BeliefTimelineTrend { strengthening, weakening, stable, unknown }

class BeliefTimeline {
  const BeliefTimeline({
    required this.points,
    required this.firstSeen,
    required this.peakLabel,
    required this.peakPercent,
    required this.currentPercent,
    required this.currentLabel,
    required this.trend,
  });

  final List<BeliefTimelinePoint> points;
  final DateTime? firstSeen;
  final String peakLabel;
  final int peakPercent;
  final int currentPercent;
  final String currentLabel;
  final BeliefTimelineTrend trend;

  static const empty = BeliefTimeline(
    points: [],
    firstSeen: null,
    peakLabel: '—',
    peakPercent: 0,
    currentPercent: 0,
    currentLabel: 'Unknown',
    trend: BeliefTimelineTrend.unknown,
  );
}

/// Full explanation payload for [ArchiveExplanationScreen].
class ArchiveExplanation {
  const ArchiveExplanation({
    required this.insightId,
    required this.kind,
    required this.title,
    required this.explanation,
    required this.whySummary,
    required this.supportingEvidence,
    required this.contradictingEvidence,
    required this.relatedThemes,
    required this.relatedBeliefs,
    required this.relatedBlindSpots,
    required this.relatedContradictions,
    required this.timeline,
    required this.confidence,
    this.beliefStatement,
    this.hasDeeperContent = false,
  });

  final String insightId;
  final ArchiveInsightKind kind;
  final String title;
  final String explanation;
  final String whySummary;
  final List<EvidenceReference> supportingEvidence;
  final List<EvidenceReference> contradictingEvidence;
  final List<RelatedTheme> relatedThemes;
  final List<RelatedBelief> relatedBeliefs;
  final List<RelatedBlindSpot> relatedBlindSpots;
  final List<RelatedContradiction> relatedContradictions;
  final BeliefTimeline timeline;
  final double confidence;
  final String? beliefStatement;
  final bool hasDeeperContent;

  List<String> get allEntryIds => [
        ...supportingEvidence.map((e) => e.entryId),
        ...contradictingEvidence.map((e) => e.entryId),
      ].toSet().toList();
}

/// Surprise pattern for "Your Archive Noticed".
class UnexpectedObservation {
  const UnexpectedObservation({
    required this.headline,
    required this.body,
    required this.evidenceEntryIds,
    required this.confidence,
  });

  final String headline;
  final String body;
  final List<String> evidenceEntryIds;
  final int confidence;
}

/// Challenge insight — archive may disagree with self-image.
class ChallengeInsight {
  const ChallengeInsight({
    required this.headline,
    required this.body,
    required this.evidenceEntryIds,
    required this.confidence,
  });

  final String headline;
  final String body;
  final List<String> evidenceEntryIds;
  final int confidence;
}

/// Card shown in Discover surprise feed.
class ArchiveNoticedItem {
  const ArchiveNoticedItem({
    required this.ref,
    required this.headline,
    required this.preview,
    required this.isChallenge,
    required this.isGold,
  });

  final ArchiveInsightRef ref;
  final String headline;
  final String preview;
  final bool isChallenge;
  final bool isGold;
}
