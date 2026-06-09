import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../theme_tracking/theme_track.dart';
import '../theme_tracking/theme_tracker_service.dart';

/// Thresholds for Early Archive Wins V1 (local engines only — no AI).
abstract final class EarlyArchiveWinsThresholds {
  EarlyArchiveWinsThresholds._();

  static const int topicMentionMinRecordings = 3;
  static const int patternFormingMinRecordings = 5;
  static const int minMentionsInWindow = 2;
  static const int maxTopicWindow = 5;
}

enum EarlyArchiveInsightKind {
  /// "You've mentioned {topic} in {N} of your last {M} recordings."
  topicInRecentWindow,

  /// "A pattern may be forming around: {theme}"
  patternMayBeForming,
}

/// A single early win surfaced from themes / tags (no LLM).
class EarlyArchiveInsight {
  const EarlyArchiveInsight({
    required this.kind,
    required this.message,
    required this.topicLabel,
    required this.mentionCount,
    required this.windowSize,
    required this.totalRecordings,
  });

  final EarlyArchiveInsightKind kind;
  final String message;
  final String topicLabel;
  final int mentionCount;
  final int windowSize;
  final int totalRecordings;
}

/// Result of [buildEarlyArchiveInsight] — at most one primary win for UI.
class EarlyArchiveWinsView {
  const EarlyArchiveWinsView({this.insight});

  final EarlyArchiveInsight? insight;

  bool get hasInsight => insight != null;
}

/// Builds the best early archive win for the current journal.
EarlyArchiveWinsView buildEarlyArchiveWins(List<JournalEntry> entries) {
  final working = _workingEntries(entries);
  final count = working.length;
  if (count < EarlyArchiveWinsThresholds.topicMentionMinRecordings) {
    return const EarlyArchiveWinsView();
  }

  final tracking = const ThemeTrackerService().track(entries: entries);
  if (tracking.topThemes.isEmpty) {
    return const EarlyArchiveWinsView();
  }

  if (count >= EarlyArchiveWinsThresholds.patternFormingMinRecordings) {
    final pattern = _patternInsight(working, tracking.topThemes);
    if (pattern != null) {
      return EarlyArchiveWinsView(insight: pattern);
    }
  }

  final topic = _topicMentionInsight(working);
  if (topic != null) {
    return EarlyArchiveWinsView(insight: topic);
  }

  return const EarlyArchiveWinsView();
}

EarlyArchiveInsight? _patternInsight(
  List<JournalEntry> working,
  List<ArchiveTheme> topThemes,
) {
  final top = topThemes.first;
  if (top.frequency < EarlyArchiveWinsThresholds.minMentionsInWindow) {
    return null;
  }

  final label = top.name;
  return EarlyArchiveInsight(
    kind: EarlyArchiveInsightKind.patternMayBeForming,
    message: 'A pattern may be forming around: $label',
    topicLabel: label,
    mentionCount: top.frequency,
    windowSize: working.length.clamp(
      EarlyArchiveWinsThresholds.topicMentionMinRecordings,
      EarlyArchiveWinsThresholds.maxTopicWindow,
    ),
    totalRecordings: working.length,
  );
}

EarlyArchiveInsight? _topicMentionInsight(List<JournalEntry> working) {
  final count = working.length;
  final windowSize = count.clamp(
    EarlyArchiveWinsThresholds.topicMentionMinRecordings,
    EarlyArchiveWinsThresholds.maxTopicWindow,
  );
  final window = working.sublist(count - windowSize);

  String? bestId;
  var bestHits = 0;
  for (final id in ThemeTrackerService.canonicalThemeIds) {
    final hits = window
        .where((e) => ThemeTrackerService.themesForEntry(e).contains(id))
        .length;
    if (hits > bestHits) {
      bestHits = hits;
      bestId = id;
    }
  }

  if (bestId == null || bestHits < EarlyArchiveWinsThresholds.minMentionsInWindow) {
    return null;
  }

  final topic =
      ThemeTrackerService.displayNames[bestId] ?? _titleCase(bestId);

  return EarlyArchiveInsight(
    kind: EarlyArchiveInsightKind.topicInRecentWindow,
    message:
        "You've mentioned $topic in $bestHits of your last $windowSize recordings.",
    topicLabel: topic,
    mentionCount: bestHits,
    windowSize: windowSize,
    totalRecordings: count,
  );
}

List<JournalEntry> _workingEntries(List<JournalEntry> entries) {
  final eligible = archiveEligibleEvidenceEntries(entries);
  if (eligible.isNotEmpty) return eligible;
  return entries.where((e) => e.transcript.trim().isNotEmpty).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}
