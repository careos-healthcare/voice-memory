import '../../design/warm_archive_copy.dart';
import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../daily_discoveries/daily_discovery_models.dart';
import 'living_archive_models.dart';

/// Curiosity-first copy for Living Archive — no new engines, strings only.
abstract final class LivingArchiveCopy {
  LivingArchiveCopy._();

  static const int minConfidenceChangePercent = 10;

  /// Recent window for “last N recordings” phrasing.
  static const int recentRecordingWindow = 3;

  static const String archiveQuestion = 'What has my archive learned?';

  static const String stillLearning = 'Your archive is still learning.';

  static const String oneMoreRecording =
      'One more recording may reveal a stronger pattern.';

  static const String viewMoreLabel = 'View More';

  static String confidenceChangeHeadline(int prior, int current) =>
      WarmArchiveCopy.confidenceShiftPhrase(prior: prior, current: current);

  static String sectionLabelFor({
    required MostImportantInsightPriority priority,
    bool isArchiveWasWrong = false,
  }) {
    if (isArchiveWasWrong || priority == MostImportantInsightPriority.archiveWasWrong) {
      return WarmArchiveCopy.archiveChangedMindSectionTitle;
    }
    return 'YOUR ARCHIVE NOTICED';
  }

  static String curiosityHeadlineForPriority(MostImportantInsightPriority priority) {
    return switch (priority) {
      MostImportantInsightPriority.archiveWasWrong =>
        'The archive changed its mind.',
      MostImportantInsightPriority.confidenceChanged => 'This pattern changed.',
      MostImportantInsightPriority.dailyDiscovery =>
        'Your archive noticed something.',
      MostImportantInsightPriority.challenge => 'The evidence shifted.',
      MostImportantInsightPriority.beliefChange => 'This belief is weakening.',
      MostImportantInsightPriority.returnReason =>
        'Your archive is still uncertain.',
    };
  }

  static String curiosityHeadlineForDailyType(DailyDiscoveryType type) {
    return switch (type) {
      DailyDiscoveryType.newBelief => 'Your archive noticed something.',
      DailyDiscoveryType.beliefStrengthening => 'This belief is strengthening.',
      DailyDiscoveryType.beliefWeakening => 'This belief is weakening.',
      DailyDiscoveryType.contradictionEmerging => 'The evidence shifted.',
      DailyDiscoveryType.contradictionResolved => 'This pattern changed.',
      DailyDiscoveryType.themeSpike => 'Your archive noticed something.',
      DailyDiscoveryType.themeDecline => 'This pattern changed.',
      DailyDiscoveryType.chapterTransition => 'Your archive noticed something.',
      DailyDiscoveryType.emotionalShift => 'This pattern changed.',
      DailyDiscoveryType.unexpectedCorrelation => 'The evidence shifted.',
    };
  }

  /// “You mentioned uncertainty 5 times in your last 3 recordings.”
  static String mentionCountInRecentRecordings({
    required String themeLabel,
    required List<JournalEntry> entries,
    required List<String> keywords,
    int recordingWindow = recentRecordingWindow,
  }) {
    final recent = lastNEligible(entries, recordingWindow);
    if (recent.isEmpty) return stillLearning;

    var mentions = 0;
    for (final e in recent) {
      mentions += _keywordHitsInEntry(e, keywords);
    }

    final n = recent.length;
    if (mentions == 0) {
      return 'You have not mentioned $themeLabel much in your last $n '
          '${n == 1 ? 'recording' : 'recordings'}.';
    }

    return 'You mentioned $themeLabel $mentions '
        '${mentions == 1 ? 'time' : 'times'} in your last $n '
        '${n == 1 ? 'recording' : 'recordings'}.';
  }

  static String themeDominanceWrongHeadline({
    required String priorThemeKey,
    required String currentThemeKey,
  }) {
    if (_isWorkOrStress(priorThemeKey) &&
        _isRelationship(currentThemeKey)) {
      return 'Your archive no longer believes work is your biggest source of stress.';
    }
    if (_isWorkOrStress(priorThemeKey)) {
      return 'Your archive no longer weights ${_label(priorThemeKey)} the way it used to.';
    }
    return 'Relationships now appear more often in your recordings.';
  }

  static String beliefTrendLabel(BeliefConfidenceTrend trend) =>
      WarmArchiveCopy.beliefTrendLabel(trend);

  static List<JournalEntry> lastNEligible(List<JournalEntry> entries, int n) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.isEmpty) return const [];
    final start = eligible.length > n ? eligible.length - n : 0;
    return eligible.sublist(start);
  }

  static int _keywordHitsInEntry(JournalEntry entry, List<String> keywords) {
    final blob = [
      entry.transcript,
      entry.reflection.exactLanguagePattern,
      entry.reflection.concreteObservation,
    ].join(' ').toLowerCase();

    var hits = 0;
    for (final kw in keywords) {
      final k = kw.toLowerCase();
      var index = 0;
      while (true) {
        final found = blob.indexOf(k, index);
        if (found < 0) break;
        hits++;
        index = found + k.length;
      }
    }
    return hits;
  }

  static bool _isWorkOrStress(String key) =>
      key == 'work' || key == 'career' || key == 'stress';

  static bool _isRelationship(String key) =>
      key == 'relationship' || key == 'relationships';

  static String _label(String key) {
    const labels = {
      'work': 'work',
      'career': 'work',
      'stress': 'stress',
      'relationship': 'relationships',
      'relationships': 'relationships',
      'confidence': 'confidence',
      'approval': 'approval',
    };
    return labels[key] ?? key;
  }
}
