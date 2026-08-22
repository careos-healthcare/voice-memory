import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/theme_tracking/theme_track.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Tracks recurring archive themes across reflections.
class ThemeTrackerService {
  const ThemeTrackerService();

  static const List<String> canonicalThemeIds = [
    'approval',
    'confidence',
    'avoidance',
    'relationships',
    'career',
    'money',
    'health',
  ];

  static const Map<String, String> displayNames = {
    'approval': 'Approval',
    'confidence': 'Confidence',
    'avoidance': 'Avoidance',
    'relationships': 'Relationships',
    'career': 'Career',
    'money': 'Money',
    'health': 'Health',
  };

  ThemeTrackingResult track({
    required List<JournalEntry> entries,
    Map<String, int>? baselineCounts,
    int topLimit = 7,
  }) {
    final eligible = _eligibleEntries(entries);
    if (eligible.isEmpty) {
      return const ThemeTrackingResult(topThemes: []);
    }

    final hits = <String, List<JournalEntry>>{
      for (final id in canonicalThemeIds) id: [],
    };

    for (final entry in eligible) {
      final matched = _matchThemes(entry);
      for (final id in matched) {
        hits[id]!.add(entry);
      }
    }

    final themes = <ArchiveTheme>[];
    for (final id in canonicalThemeIds) {
      final list = hits[id]!;
      if (list.isEmpty) continue;
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      themes.add(
        ArchiveTheme(
          name: displayNames[id] ?? _titleCase(id),
          frequency: list.length,
          trend: _trendFor(
            themeId: id,
            matches: list,
            allEligible: eligible,
            baseline:
                baselineCounts?[id] ??
                baselineCounts?[_titleCase(id).toLowerCase()],
          ),
          firstSeen: list.first.createdAt,
          lastSeen: list.last.createdAt,
        ),
      );
    }

    themes.sort((a, b) => b.frequency.compareTo(a.frequency));
    return ThemeTrackingResult(topThemes: themes.take(topLimit).toList());
  }

  /// Canonical theme ids detected in one journal entry.
  static Set<String> themesForEntry(JournalEntry entry) => _matchThemes(entry);

  /// Maps discover baseline keys to canonical theme ids when present.
  static Map<String, int>? canonicalBaselineFromStored(Map<String, int>? raw) {
    if (raw == null || raw.isEmpty) return null;
    final out = <String, int>{};
    for (final id in canonicalThemeIds) {
      final count = raw[id] ?? 0;
      if (count > 0) out[id] = count;
    }
    return out.isEmpty ? null : out;
  }
}

List<JournalEntry> _eligibleEntries(List<JournalEntry> entries) {
  final withTranscript = entries
      .where((e) => e.transcript.trim().length >= archiveMinTranscriptChars)
      .toList();
  if (withTranscript.isNotEmpty) {
    return withTranscript..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  return entries.where((e) => e.transcript.trim().isNotEmpty).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

Set<String> _matchThemes(JournalEntry entry) {
  final blob = _entryText(entry).toLowerCase();
  final matched = <String>{};

  for (final id in ThemeTrackerService.canonicalThemeIds) {
    if (_themeKeywords[id]!.any(blob.contains)) {
      matched.add(id);
    }
  }

  for (final raw in entry.reflection.recurringThemes) {
    final t = raw.trim().toLowerCase();
    for (final id in ThemeTrackerService.canonicalThemeIds) {
      if (t == id || t.contains(id)) matched.add(id);
    }
  }

  return matched;
}

String _entryText(JournalEntry entry) {
  return [
    entry.transcript,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    entry.reflection.repeatedSignal,
    entry.reflection.mood,
    entry.reflection.tensionOrContradiction ?? '',
    entry.reflection.avoidedOrVagueArea ?? '',
    ...entry.reflection.recurringThemes,
  ].join(' ');
}

ThemeTrend _trendFor({
  required String themeId,
  required List<JournalEntry> matches,
  required List<JournalEntry> allEligible,
  int? baseline,
}) {
  if (baseline != null) {
    final current = matches.length;
    if (current > baseline) return ThemeTrend.up;
    if (current < baseline && baseline >= 2) return ThemeTrend.down;
    return ThemeTrend.stable;
  }

  if (matches.length < 2 || allEligible.length < 4) {
    return matches.length >= 2 ? ThemeTrend.up : ThemeTrend.stable;
  }

  final midpoint = allEligible.length ~/ 2;
  final splitAt = allEligible[midpoint].createdAt;
  var early = 0;
  var late = 0;
  for (final m in matches) {
    if (m.createdAt.isBefore(splitAt)) {
      early++;
    } else {
      late++;
    }
  }

  if (late > early) return ThemeTrend.up;
  // Require recent-period hits before calling a theme declining.
  if (early > late && early >= 2 && late >= 1) return ThemeTrend.down;
  return ThemeTrend.stable;
}

String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}

const Map<String, List<String>> _themeKeywords = {
  'approval': [
    'approval',
    'approve',
    'validation',
    'people-pleas',
    'people pleas',
    'need praise',
    'seek praise',
    'liked by',
  ],
  'confidence': [
    'confidence',
    'confident',
    'self-trust',
    'trust my judgment',
    'trust myself',
    'assertive',
    'self-worth',
  ],
  'avoidance': [
    'avoid',
    'avoidance',
    'procrastinat',
    'put off',
    'escape',
    'withdraw',
    'hide from',
  ],
  'relationships': [
    'relationship',
    'partner',
    'spouse',
    'marriage',
    'family',
    'friend',
    'dating',
    'breakup',
  ],
  'career': [
    'career',
    'job',
    'work',
    'office',
    'promotion',
    'manager',
    'networking',
    'colleague',
  ],
  'money': [
    'money',
    'financial',
    'income',
    'salary',
    'debt',
    'savings',
    'budget',
    'afford',
  ],
  'health': [
    'health',
    'sleep',
    'exercise',
    'burnout',
    'energy',
    'therapy',
    'wellness',
    'anxious',
    'anxiety',
  ],
};