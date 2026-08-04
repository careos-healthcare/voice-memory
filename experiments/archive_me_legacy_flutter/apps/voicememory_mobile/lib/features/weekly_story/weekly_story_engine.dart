import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_state_object/archive_state_object.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import '../discover/chapter_engine.dart';
import '../discover/theme_engine.dart';
import 'weekly_story_models.dart';

/// Builds “Your Week in Reflection” from real journal evidence only.
class WeeklyStoryEngine {
  const WeeklyStoryEngine();

  static int get minEntriesForCard => ArchiveEvidenceGuard.minimumEvidenceCount;

  WeeklyArchiveStory? build({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DateTime? now,
  }) {
    if (!ArchiveEvidenceGuard.canSurfaceWeeklyStory(entries)) return null;

    final clock = now ?? DateTime.now();
    final weekEnd = DateTime(clock.year, clock.month, clock.day, 23, 59, 59);
    final weekStart = weekEnd.subtract(const Duration(days: 6));
    final priorStart = weekStart.subtract(const Duration(days: 7));

    final thisWeek = entries.where((e) {
      final t = e.createdAt;
      return !t.isBefore(weekStart) && !t.isAfter(weekEnd);
    }).toList();
    final priorWeek = entries.where((e) {
      final t = e.createdAt;
      return !t.isBefore(priorStart) && t.isBefore(weekStart);
    }).toList();

    final currentCounts = DiscoverLocalThemeCounts.count(thisWeek);
    final priorCounts = DiscoverLocalThemeCounts.count(priorWeek);

    final topThemes = currentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final themeLines = topThemes
        .take(5)
        .map(
          (e) => WeeklyThemeLine(
            label: _label(e.key),
            count: e.value,
            priorCount: priorCounts[e.key] ?? 0,
          ),
        )
        .where((t) => t.count > 0)
        .toList();

    final growing = <WeeklyThemeLine>[];
    final declining = <WeeklyThemeLine>[];
    for (final e in currentCounts.entries) {
      final label = _label(e.key);
      final cur = e.value;
      final prev = priorCounts[e.key] ?? 0;
      if (cur > prev && cur >= 2) {
        growing.add(
          WeeklyThemeLine(label: label, count: cur, priorCount: prev),
        );
      } else if (prev > cur && prev >= 2) {
        declining.add(
          WeeklyThemeLine(label: label, count: cur, priorCount: prev),
        );
      }
    }
    growing.sort(
      (a, b) => (b.count - b.priorCount).compareTo(a.count - a.priorCount),
    );
    declining.sort(
      (a, b) => (b.priorCount - b.count).compareTo(a.priorCount - a.count),
    );

    String? belief;
    if (archiveHasMinimumEvidence(entries)) {
      belief =
          state?.belief?.trim() ??
          archiveBeliefFromReflections(entries)?.trim();
      if (belief != null && belief.isEmpty) belief = null;
    }

    // Require at least some weekly activity or themes to avoid empty story.
    final hasSufficientData =
        thisWeek.isNotEmpty || themeLines.isNotEmpty || belief != null;

    if (!hasSufficientData) return null;

    return WeeklyArchiveStory(
      weekStart: weekStart,
      weekEnd: weekEnd,
      topThemes: themeLines,
      growingThemes: growing.take(3).toList(),
      decliningThemes: declining.take(3).toList(),
      primaryBelief: belief,
      reflectionCountThisWeek: thisWeek.length,
      hasSufficientData: true,
    );
  }

  int contradictionCountThisWeek(List<JournalEntry> entries, String? belief) {
    final result = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: belief,
    );
    return result.reports.length;
  }

  int chapterCount(List<JournalEntry> entries) =>
      const DiscoverChapterEngine().build(entries).length;

  /// Creates a short, deterministic script suitable for text-to-speech.
  ///
  /// Every statement is derived from [story]; no new interpretation or
  /// evidence is introduced during narration.
  String buildAudioRetrospective(WeeklyArchiveStory story) {
    final sentences = <String>[
      'Weekly Audio Retrospective.',
      story.reflectionCountThisWeek == 1
          ? 'You saved one moment this week.'
          : 'You saved ${story.reflectionCountThisWeek} moments this week.',
    ];

    if (story.topThemes.isNotEmpty) {
      final themes = story.topThemes
          .take(3)
          .map((theme) => theme.label)
          .toList();
      sentences.add(
        'The themes that appeared most were ${_spokenList(themes)}.',
      );
    }

    if (story.growingThemes.isNotEmpty) {
      final theme = story.growingThemes.first;
      sentences.add(
        '${theme.label} returned more often than in the previous week.',
      );
    }

    if (story.decliningThemes.isNotEmpty) {
      final theme = story.decliningThemes.first;
      sentences.add(
        '${theme.label} appeared less often than in the previous week.',
      );
    }

    final belief = story.primaryBelief?.trim();
    if (belief != null && belief.isNotEmpty) {
      sentences.add('One belief your archive is tracking is: $belief.');
    }

    sentences.add(
      'This retrospective is based only on the moments in your archive.',
    );
    return sentences.join(' ');
  }

  static String _spokenList(List<String> values) {
    if (values.isEmpty) return '';
    if (values.length == 1) return values.first;
    if (values.length == 2) return '${values.first} and ${values.last}';
    return '${values.sublist(0, values.length - 1).join(', ')}, and ${values.last}';
  }

  static String _label(String key) {
    const map = {
      'career': 'Career',
      'work': 'Work',
      'confidence': 'Confidence',
      'relationship': 'Relationships',
      'relationships': 'Relationships',
      'health': 'Health',
      'family': 'Family',
      'stress': 'Stress',
      'money': 'Money',
      'purpose': 'Purpose',
    };
    return map[key] ??
        (key.isEmpty ? key : key[0].toUpperCase() + key.substring(1));
  }
}
