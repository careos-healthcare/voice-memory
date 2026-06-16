import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_state_object/archive_state_object.dart';
import '../belief_change/belief_change_detector.dart';
import '../belief_change/belief_change_models.dart';
import '../belief_shift/belief_shift_engine.dart';
import '../belief_shift/belief_shift_models.dart';
import 'belief_engine.dart';
import 'blind_spot_engine.dart';
import 'chapter_engine.dart';
import 'contradiction_engine.dart';
import 'discover_cache.dart';
import 'discover_models.dart';
import 'growth_timeline_engine.dart';
import 'theme_engine.dart';

/// Orchestrates local insight engines for the Discover Yourself dashboard.
class DiscoverYourselfEngine {
  const DiscoverYourselfEngine({
    this.beliefEngine = const DiscoverBeliefEngine(),
    this.themeEngine = const DiscoverThemeEngine(),
    this.contradictionEngine = const DiscoverContradictionEngine(),
    this.blindSpotEngine = const DiscoverBlindSpotEngine(),
    this.chapterEngine = const DiscoverChapterEngine(),
    this.growthEngine = const DiscoverGrowthTimelineEngine(),
    this.beliefChangeDetector = const BeliefChangeDetector(),
    this.beliefShiftEngine = const BeliefShiftEngine(),
  });

  final DiscoverBeliefEngine beliefEngine;
  final DiscoverThemeEngine themeEngine;
  final DiscoverContradictionEngine contradictionEngine;
  final DiscoverBlindSpotEngine blindSpotEngine;
  final DiscoverChapterEngine chapterEngine;
  final DiscoverGrowthTimelineEngine growthEngine;
  final BeliefChangeDetector beliefChangeDetector;
  final BeliefShiftEngine beliefShiftEngine;

  DiscoverYourselfCache get cache => DiscoverYourselfCache.instance;

  static const askPrompts = [
    'What changed most?',
    'What do I keep repeating?',
    'What am I avoiding?',
    'What matters most to me?',
    'What am I becoming more confident about?',
  ];

  DiscoverYourselfSnapshot build({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    Map<String, int>? themeBaseline,
    bool useCache = true,
  }) {
    final fp = DiscoverYourselfCache.fingerprint(entries);
    if (useCache) {
      final cached = cache.getIfValid(fp);
      if (cached != null) return cached;
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    final mode = DiscoverInsightMode.forCount(entries.length);
    final header = _headerStats(entries, eligible);
    final belief = beliefEngine.build(entries: entries, state: state);

    final showEarly =
        mode == DiscoverInsightMode.growing || mode == DiscoverInsightMode.full;
    final showFull = mode == DiscoverInsightMode.full;

    final beliefChanges = showEarly
        ? _beliefChanges(entries, state)
        : const <DiscoverBeliefChange>[];

    final themes = showEarly
        ? themeEngine.build(entries: entries, baselineThemes: themeBaseline)
        : const <DiscoverThemeInsight>[];

    final contradictions = showFull
        ? contradictionEngine.build(entries: entries, state: state)
        : const <DiscoverContradictionInsight>[];

    final blindSpots = showFull
        ? blindSpotEngine.build(entries)
        : const <DiscoverBlindSpotCard>[];

    final chapters = showFull
        ? chapterEngine.build(entries)
        : const <DiscoverChapterSummary>[];

    final momentum = showEarly ? _momentum(entries, eligible) : null;

    final growthTimeline = showEarly
        ? growthEngine.build(entries)
        : const <DiscoverGrowthMonth>[];

    final snapshot = DiscoverYourselfSnapshot(
      mode: mode,
      generatedAt: DateTime.now(),
      header: header,
      belief: belief,
      beliefChanges: beliefChanges,
      themes: themes,
      contradictions: contradictions,
      blindSpots: blindSpots,
      chapters: chapters,
      momentum: momentum,
      growthTimeline: growthTimeline,
      askPrompts: askPrompts,
    );

    cache.put(fp, snapshot);
    return snapshot;
  }

  DiscoverArchiveAnswer? answerArchiveQuestion({
    required String prompt,
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) {
    if (entries.isEmpty) return null;
    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.isEmpty) {
      return DiscoverArchiveAnswer(
        prompt: prompt,
        answerLines: const [
          'Not enough transcript detail yet — keep recording so the archive can cite real lines.',
        ],
        citedEntryIds: const [],
      );
    }

    switch (prompt) {
      case 'What changed most?':
        return _answerWhatChangedMost(entries, state);
      case 'What do I keep repeating?':
        return _answerRepeating(entries);
      case 'What am I avoiding?':
        return _answerAvoiding(entries);
      case 'What matters most to me?':
        return _answerWhatMatters(entries, state);
      case 'What am I becoming more confident about?':
        return _answerGrowingConfidence(entries);
      default:
        return null;
    }
  }

  DiscoverHeaderStats _headerStats(
    List<JournalEntry> all,
    List<JournalEntry> eligible,
  ) {
    if (all.isEmpty) {
      return const DiscoverHeaderStats(
        totalRecordings: 0,
        totalReflections: 0,
        daysTracked: 0,
      );
    }

    final sorted = [...all]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final days = all.map((e) {
      final d = e.createdAt.toLocal();
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    return DiscoverHeaderStats(
      totalRecordings: all.length,
      totalReflections: eligible.length,
      daysTracked: days.length,
      firstRecordingDate: sorted.first.createdAt,
    );
  }

  List<DiscoverBeliefChange> _beliefChanges(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final alerts = beliefChangeDetector.detect(entries: entries, state: state);
    return alerts.map(_beliefChangeFromAlert).toList();
  }

  DiscoverBeliefChange _beliefChangeFromAlert(BeliefChangeAlert alert) {
    return DiscoverBeliefChange(
      type: alert.type.name,
      headline: alert.headline,
      beliefStatement: alert.beliefStatement,
      priorLabel: alert.priorLabel,
      priorPercent: alert.priorPercent,
      currentLabel: alert.currentLabel,
      currentPercent: alert.currentPercent,
      magnitude: alert.magnitude,
      evidenceEntryIds: alert.evidenceEntryIds,
      confidence: alert.confidence,
      dateRangeLabel: alert.confidenceRangeLabel,
    );
  }

  DiscoverMomentumStats _momentum(
    List<JournalEntry> all,
    List<JournalEntry> eligible,
  ) {
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));

    int recordingsThisWeek = 0;
    int reflectionsThisWeek = 0;
    for (final e in all) {
      if (!e.createdAt.isAfter(weekStart)) continue;
      recordingsThisWeek++;
    }
    for (final e in eligible) {
      if (!e.createdAt.isAfter(weekStart)) continue;
      reflectionsThisWeek++;
    }

    final streaks = _computeStreaks(all);
    return DiscoverMomentumStats(
      recordingsThisWeek: recordingsThisWeek,
      reflectionsThisWeek: reflectionsThisWeek,
      longestStreak: streaks.$1,
      currentStreak: streaks.$2,
    );
  }

  (int longest, int current) _computeStreaks(List<JournalEntry> entries) {
    if (entries.isEmpty) return (0, 0);

    final days =
        entries
            .map((e) {
              final d = e.createdAt.toLocal();
              return DateTime(d.year, d.month, d.day);
            })
            .toSet()
            .toList()
          ..sort();

    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      if (diff == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    var current = 0;
    var cursor = todayDate;
    final daySet = days.toSet();
    while (daySet.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return (longest, current);
  }

  DiscoverArchiveAnswer _answerWhatChangedMost(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final shifts = beliefShiftEngine.detect(
      entries: entries,
      currentBelief: state?.belief,
    );
    if (shifts.reports.isNotEmpty) {
      final top = shifts.reports.first;
      return DiscoverArchiveAnswer(
        prompt: 'What changed most?',
        answerLines: [
          'The largest shift the archive sees is from:',
          '“${top.originalBelief}”',
          'toward:',
          '“${top.newBelief}”.',
        ],
        citedEntryIds: top.evidenceIds.take(4).toList(),
      );
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length >= 2) {
      final first = eligible.first;
      final last = eligible.last;
      return DiscoverArchiveAnswer(
        prompt: 'What changed most?',
        answerLines: [
          'Early archive tone: “${_clip(first.transcript)}”',
          'Recent tone: “${_clip(last.transcript)}”',
        ],
        citedEntryIds: [first.id, last.id],
      );
    }

    return DiscoverArchiveAnswer(
      prompt: 'What changed most?',
      answerLines: const [
        'Keep recording — a before/after arc needs more history.',
      ],
      citedEntryIds: const [],
    );
  }

  DiscoverArchiveAnswer _answerRepeating(List<JournalEntry> entries) {
    final themes = DiscoverLocalThemeCounts.count(entries);
    if (themes.isEmpty) {
      return DiscoverArchiveAnswer(
        prompt: 'What do I keep repeating?',
        answerLines: const [
          'Themes are still emerging — add a few more reflections.',
        ],
        citedEntryIds: const [],
      );
    }
    final top = themes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final key = top.first.key;
    final ids = DiscoverThemeEngine()
        .build(entries: entries)
        .firstWhere(
          (t) => t.themeKey == key,
          orElse: () => DiscoverThemeInsight(
            name: key,
            themeKey: key,
            frequency: top.first.value,
            trend: ThemeTrendDirection.flat,
          ),
        );
    return DiscoverArchiveAnswer(
      prompt: 'What do I keep repeating?',
      answerLines: [
        '“${ids.name}” appears in ${top.first.value} reflections — the most repeated theme so far.',
      ],
      citedEntryIds: ids.evidenceEntryIds,
    );
  }

  DiscoverArchiveAnswer _answerAvoiding(List<JournalEntry> entries) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    final avoid = eligible.where((e) {
      final t = e.transcript.toLowerCase();
      return t.contains('avoid') ||
          t.contains("don't want") ||
          t.contains('hard to') ||
          t.contains('procrastinat');
    }).toList();

    if (avoid.isEmpty) {
      return DiscoverArchiveAnswer(
        prompt: 'What am I avoiding?',
        answerLines: const [
          'No explicit avoidance language yet — the archive will surface it when you name it in a recording.',
        ],
        citedEntryIds: const [],
      );
    }

    final recent = avoid.last;
    return DiscoverArchiveAnswer(
      prompt: 'What am I avoiding?',
      answerLines: [
        'Recent lines mention tension or delay:',
        '“${_clip(recent.transcript)}”',
      ],
      citedEntryIds: avoid.reversed.take(3).map((e) => e.id).toList(),
    );
  }

  DiscoverArchiveAnswer _answerWhatMatters(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final belief =
        state?.belief?.trim() ?? archiveBeliefFromReflections(entries);
    if (belief != null && belief.isNotEmpty) {
      final cited = archiveEligibleEvidenceEntries(
        entries,
      ).reversed.take(2).map((e) => e.id).toList();
      return DiscoverArchiveAnswer(
        prompt: 'What matters most to me?',
        answerLines: [
          'Your archive currently weights this as central:',
          '“$belief”',
        ],
        citedEntryIds: cited,
      );
    }

    final themes = DiscoverLocalThemeCounts.count(entries);
    if (themes.isNotEmpty) {
      final top = themes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return DiscoverArchiveAnswer(
        prompt: 'What matters most to me?',
        answerLines: [
          'Recurring focus: ${top.first.key} (${top.first.value} mentions).',
        ],
        citedEntryIds: const [],
      );
    }

    return DiscoverArchiveAnswer(
      prompt: 'What matters most to me?',
      answerLines: const [
        'Record a few more reflections so patterns can form.',
      ],
      citedEntryIds: const [],
    );
  }

  DiscoverArchiveAnswer _answerGrowingConfidence(List<JournalEntry> entries) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    final confident = eligible.where((e) {
      final t = e.transcript.toLowerCase();
      return t.contains('confident') ||
          t.contains('clearer') ||
          t.contains('proud') ||
          t.contains('ready');
    }).toList();

    if (confident.isEmpty) {
      return DiscoverArchiveAnswer(
        prompt: 'What am I becoming more confident about?',
        answerLines: const [
          'Confidence language is still sparse — celebrate small wins in your next recording.',
        ],
        citedEntryIds: const [],
      );
    }

    final recent = confident.last;
    return DiscoverArchiveAnswer(
      prompt: 'What am I becoming more confident about?',
      answerLines: [
        'Recent recordings sound more assured:',
        '“${_clip(recent.transcript)}”',
      ],
      citedEntryIds: confident.reversed.take(3).map((e) => e.id).toList(),
    );
  }

  static String _clip(String text, {int max = 100}) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  static String _monthYearRange(DateTime start, DateTime end) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final a = '${months[start.month - 1]} ${start.year}';
    final b = '${months[end.month - 1]} ${end.year}';
    if (a == b) return a;
    return '$a – $b';
  }
}
