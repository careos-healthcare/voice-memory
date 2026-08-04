import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../theme_tracking/theme_tracker_service.dart';
import 'archive_v1_models.dart';

/// Evidence-only contradictions: stated importance vs low mention frequency.
class ArchiveThemeGapEngine {
  const ArchiveThemeGapEngine({
    this.minConfidence = 60,
    this.minEligible = 5,
    this.maxSharePercentForGap = 12,
  });

  final int minConfidence;
  final int minEligible;
  final int maxSharePercentForGap;

  static const _importancePhrases = [
    'matter most',
    'matters most',
    'most important',
    'really important',
    'so important',
    'priority',
    'care about',
    'care most',
  ];

  static const _themeKeywords = <String, List<String>>{
    'relationships': [
      'relationship',
      'partner',
      'marriage',
      'family',
      'friend',
    ],
    'health': ['health', 'sleep', 'exercise', 'body', 'energy', 'tired'],
    'career': ['career', 'work', 'job', 'manager', 'promotion'],
    'money': ['money', 'finance', 'financial', 'salary', 'savings'],
    'confidence': ['confidence', 'self-doubt', 'imposter', 'capable'],
    'approval': ['approval', 'validate', 'people-pleas', 'liked'],
    'avoidance': ['avoid', 'procrastinat', 'delay', 'put off'],
  };

  List<ArchiveV1Contradiction> build(List<JournalEntry> entries) {
    if (!archiveHasMinimumEvidence(entries)) return const [];

    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length < minEligible) return const [];

    final total = eligible.length;
    final tracker = const ThemeTrackerService();
    final result = tracker.track(entries: entries);
    final byTheme = {
      for (final t in result.topThemes) _canonicalKey(t.name): t.frequency,
    };

    final out = <ArchiveV1Contradiction>[];

    for (final entry in _themeKeywords.entries) {
      final themeId = entry.key;
      final keywords = entry.value;
      final freq = byTheme[themeId] ?? _countMentions(eligible, keywords);
      final share = total == 0 ? 0 : ((freq / total) * 100).round();

      final importanceHits = eligible.where((e) {
        final t = e.transcript.toLowerCase();
        final mentionsTheme = keywords.any(t.contains);
        final claimsImportance =
            _importancePhrases.any(t.contains) && mentionsTheme;
        return claimsImportance;
      }).toList();

      if (importanceHits.isEmpty) continue;
      if (share > maxSharePercentForGap) continue;

      final display = ThemeTrackerService.displayNames[themeId] ?? themeId;
      final confidence = (68 + importanceHits.length * 4).clamp(
        minConfidence,
        92,
      );

      out.add(
        ArchiveV1Contradiction(
          id: 'gap:$themeId',
          youSay: 'You describe $display as important in your saved words.',
          but:
              'Only $share% of your eligible recordings mention $display '
              '($freq of $total).',
          confidenceScore: confidence,
          entryIds: importanceHits.take(4).map((e) => e.id).toList(),
          kind: ArchiveV1ContradictionKind.themeGap,
        ),
      );
    }

    out.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    return out.take(3).toList();
  }

  int _countMentions(List<JournalEntry> eligible, List<String> keywords) {
    return eligible
        .where(
          (e) => keywords.any((k) => e.transcript.toLowerCase().contains(k)),
        )
        .length;
  }

  String _canonicalKey(String displayName) {
    final lower = displayName.toLowerCase();
    for (final id in ThemeTrackerService.canonicalThemeIds) {
      if (ThemeTrackerService.displayNames[id]?.toLowerCase() == lower) {
        return id;
      }
    }
    return lower;
  }
}
