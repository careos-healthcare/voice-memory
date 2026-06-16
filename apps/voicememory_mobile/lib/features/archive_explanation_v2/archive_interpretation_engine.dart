import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_explanations/explanation_models.dart';
import 'archive_followup_question_engine.dart';
import 'archive_interpretation_models.dart';

/// Builds evidence-grounded interpretation copy — no advice, no open-ended chat.
class ArchiveInterpretationEngine {
  const ArchiveInterpretationEngine({
    this.followUpEngine = const ArchiveFollowupQuestionEngine(),
  });

  final ArchiveFollowupQuestionEngine followUpEngine;

  static const Map<String, List<String>> _themeKeywords = {
    'approval': ['approval', 'approve', 'validation', 'validate'],
    'work': ['work', 'job', 'career', 'office', 'stress'],
    'confidence': ['confident', 'confidence', 'sure of myself'],
    'uncertainty': ['uncertain', 'unsure', 'doubt', 'anxious', 'anxiety'],
    'relationship': ['relationship', 'partner', 'family', 'friend'],
  };

  ArchiveInterpretation? build({
    required ArchiveInsightRef ref,
    required ArchiveExplanation explanation,
    required List<JournalEntry> entries,
  }) {
    if (explanation.whySummary.trim().isEmpty &&
        explanation.supportingEvidence.isEmpty &&
        explanation.contradictingEvidence.isEmpty) {
      return null;
    }

    final stats = _EvidenceStats.compute(entries, explanation);
    final whatMightMean = _whatThisMightMean(explanation, ref, entries, stats);
    final supports = _supportsSummary(explanation, stats);
    final contradicts = _contradictsSummary(explanation, stats);
    final mindChange = _mindChange(explanation, stats);
    final followUp = followUpEngine.generate(
      ref: ref,
      explanation: explanation,
      entries: entries,
    );

    return ArchiveInterpretation(
      ref: ref,
      insightId: explanation.insightId,
      kind: explanation.kind,
      title: explanation.title,
      beliefStatement: explanation.beliefStatement,
      whyText: _combineWhy(explanation),
      supportingEvidence: explanation.supportingEvidence,
      contradictingEvidence: explanation.contradictingEvidence,
      timeline: explanation.timeline,
      relatedThemes: explanation.relatedThemes,
      relatedBeliefs: explanation.relatedBeliefs,
      relatedBlindSpots: explanation.relatedBlindSpots,
      relatedContradictions: explanation.relatedContradictions,
      whatThisMightMean: whatMightMean,
      supportsSummary: supports,
      contradictsSummary: contradicts,
      mindChange: mindChange,
      followUpQuestion: followUp,
    );
  }

  static String _combineWhy(ArchiveExplanation e) {
    final parts = <String>[
      if (e.whySummary.trim().isNotEmpty) e.whySummary.trim(),
      if (e.explanation.trim().isNotEmpty &&
          e.explanation.trim() != e.whySummary.trim())
        e.explanation.trim(),
    ];
    return parts.join('\n\n');
  }

  String _whatThisMightMean(
    ArchiveExplanation e,
    ArchiveInsightRef ref,
    List<JournalEntry> entries,
    _EvidenceStats stats,
  ) {
    final sentences = <String>[];

    switch (e.kind) {
      case ArchiveInsightKind.belief:
      case ArchiveInsightKind.beliefChange:
        final belief = e.beliefStatement ?? 'this pattern';
        if (stats.uncertaintyMentions > stats.confidenceMentions &&
            stats.uncertaintyMentions >= 2) {
          sentences.add('You often describe confidence as part of the story.');
          sentences.add(
            'The archive found more references to uncertainty than confidence '
            'in eligible recordings.',
          );
          sentences.add(
            'This may suggest hesitation appears before self-doubt in your language.',
          );
        } else if (e.timeline.trend == BeliefTimelineTrend.weakening) {
          sentences.add(
            'Language tied to “${_short(belief, 64)}” may be softening across recent reflections.',
          );
          sentences.add(
            'The archive appears less certain about this story than it was earlier.',
          );
        } else if (e.timeline.trend == BeliefTimelineTrend.strengthening) {
          sentences.add(
            'The same story may be repeating with more weight in recent recordings.',
          );
          sentences.add(
            'The archive might read this as a pattern you return to rather than a one-off line.',
          );
        } else {
          sentences.add(
            '“${_short(belief, 64)}” appears across ${stats.supportingCount} recordings the archive can cite.',
          );
          sentences.add(
            'The pattern might reflect language you return to when reflecting aloud.',
          );
        }
      case ArchiveInsightKind.theme:
        final theme = e.title;
        if (stats.recentThemeMentions > stats.priorThemeMentions &&
            stats.priorThemeMentions >= 2) {
          sentences.add(
            'Mentions of $theme appear more often in your recent eligible reflections.',
          );
          sentences.add(
            'The archive may be weighting $theme more heavily than it did in the prior window.',
          );
        } else if (stats.recentThemeMentions < stats.priorThemeMentions &&
            stats.priorThemeMentions >= 3) {
          sentences.add(
            'You mention $theme less often in recent recordings than before.',
          );
          sentences.add(
            'The pattern might be fading, shifting focus, or simply quieter this month.',
          );
        } else {
          sentences.add(
            '$theme shows up in ${stats.supportingCount} reflections with usable transcripts.',
          );
          sentences.add(
            'The archive might treat this as something you return to when thinking aloud.',
          );
        }
      case ArchiveInsightKind.contradiction:
        sentences.add(
          'Two recordings pull in different directions while both remain in your archive.',
        );
        sentences.add(
          'This may mark competing needs rather than a single “correct” story.',
        );
        sentences.add(
          'The archive surfaces the tension so you can compare the evidence side by side.',
        );
      case ArchiveInsightKind.challenge:
        sentences.add(
          'The archive compared how you describe yourself with patterns in your transcripts.',
        );
        sentences.add(
          'A gap may appear between self-image and repeated language — worth testing in a new recording.',
        );
      default:
        if (stats.workMentions > stats.relationshipMentions + 2 &&
            stats.recentRelationshipMentions >
                stats.priorRelationshipMentions) {
          sentences.add(
            'The archive previously linked stress mostly to work in older reflections.',
          );
          sentences.add(
            'Recent recordings mention relationships more frequently.',
          );
          sentences.add(
            'The pattern may be shifting — not proven, but visible in your words.',
          );
        } else if (e.whySummary.isNotEmpty) {
          sentences.add(e.whySummary);
          if (stats.supportingCount >= 3) {
            sentences.add(
              'This reading draws on ${stats.supportingCount} linked recordings '
              'and ${stats.monthSpan} months of eligible entries.',
            );
          }
        }
    }

    if (sentences.isEmpty) {
      sentences.add(
        'The archive weighed ${stats.supportingCount} supporting recordings '
        'before surfacing this insight.',
      );
      sentences.add(
        'The meaning may stay open until more reflections clarify the pattern.',
      );
    }

    return _hedgedParagraph(sentences.take(4).toList());
  }

  InterpretationEvidenceSummary _supportsSummary(
    ArchiveExplanation e,
    _EvidenceStats stats,
  ) {
    final bullets = <String>[];
    if (stats.supportingCount > 0) {
      bullets.add('Appears in ${stats.supportingCount} recordings');
    }
    if (stats.monthSpan > 0) {
      bullets.add('Mentioned across ${stats.monthSpan} months');
    }
    if (stats.recentSharePercent >= 55) {
      bullets.add('Increasing recently in eligible reflections');
    } else if (stats.recentSharePercent <= 35 && stats.supportingCount >= 4) {
      bullets.add('More common in earlier recordings than the latest window');
    }
    if (e.timeline.trend == BeliefTimelineTrend.strengthening) {
      bullets.add('Timeline suggests strengthening over time');
    }

    return InterpretationEvidenceSummary(
      bullets: bullets,
      entries: e.supportingEvidence,
    );
  }

  InterpretationEvidenceSummary _contradictsSummary(
    ArchiveExplanation e,
    _EvidenceStats stats,
  ) {
    final bullets = <String>[];
    if (stats.contradictingCount > 0) {
      bullets.add(
        '${stats.contradictingCount} recordings suggest a different pattern',
      );
    }
    if (e.timeline.trend == BeliefTimelineTrend.strengthening &&
        e.kind == ArchiveInsightKind.belief) {
      bullets.add(
        'Some lines may still sound uncertain despite a strengthening trend',
      );
    }
    if (e.timeline.trend == BeliefTimelineTrend.weakening) {
      bullets.add(
        'Confidence may appear lower in the timeline than older peaks',
      );
    }
    if (stats.recentThemeMentions == 0 && stats.priorThemeMentions >= 3) {
      bullets.add('Theme absent in the most recent eligible month');
    }
    if (e.relatedContradictions.isNotEmpty) {
      bullets.add(
        '${e.relatedContradictions.length} related tension${e.relatedContradictions.length == 1 ? '' : 's'} in the archive',
      );
    }
    if (stats.independenceSignals >= 2) {
      bullets.add(
        '${stats.independenceSignals} recordings suggest independence or self-trust',
      );
    }

    return InterpretationEvidenceSummary(
      bullets: bullets,
      entries: e.contradictingEvidence,
    );
  }

  InterpretationMindChange _mindChange(
    ArchiveExplanation e,
    _EvidenceStats stats,
  ) {
    final stronger = <String>[];
    final weaker = <String>[];

    switch (e.kind) {
      case ArchiveInsightKind.belief:
      case ArchiveInsightKind.beliefChange:
        if (stats.uncertaintyMentions >= 2) {
          stronger.add('uncertainty continues appearing in new recordings');
        }
        stronger.add(
          'the same belief language repeats without counter-examples',
        );
        weaker.add('decisive or self-trusting language appears more often');
        weaker.add('the belief stops appearing in recent reflections');
      case ArchiveInsightKind.theme:
        final theme = e.title.toLowerCase();
        stronger.add('$theme continues appearing in eligible reflections');
        stronger.add(
          'older recordings are outweighed by a sustained recent cluster',
        );
        weaker.add('$theme goes quiet for several new recordings');
        weaker.add('a different theme dominates the latest month');
      case ArchiveInsightKind.contradiction:
        stronger.add('both sides of the tension keep appearing together');
        weaker.add('one side disappears from recent eligible reflections');
        weaker.add('a third theme reframes both earlier lines');
      default:
        stronger.add('the same language pattern repeats in new recordings');
        weaker.add('recent recordings contradict the earlier cluster');
    }

    return InterpretationMindChange(
      strongerIf: stronger.take(3).toList(),
      weakerIf: weaker.take(3).toList(),
    );
  }

  static String _hedgedParagraph(List<String> sentences) {
    return sentences
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\n\n');
  }

  static String _short(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}

class _EvidenceStats {
  const _EvidenceStats({
    required this.supportingCount,
    required this.contradictingCount,
    required this.monthSpan,
    required this.recentSharePercent,
    required this.confidenceMentions,
    required this.uncertaintyMentions,
    required this.workMentions,
    required this.relationshipMentions,
    required this.recentThemeMentions,
    required this.priorThemeMentions,
    required this.recentRelationshipMentions,
    required this.priorRelationshipMentions,
    required this.independenceSignals,
  });

  final int supportingCount;
  final int contradictingCount;
  final int monthSpan;
  final int recentSharePercent;
  final int confidenceMentions;
  final int uncertaintyMentions;
  final int workMentions;
  final int relationshipMentions;
  final int recentThemeMentions;
  final int priorThemeMentions;
  final int recentRelationshipMentions;
  final int priorRelationshipMentions;
  final int independenceSignals;

  static _EvidenceStats compute(
    List<JournalEntry> entries,
    ArchiveExplanation explanation,
  ) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    final supportIds = explanation.supportingEvidence
        .map((e) => e.entryId)
        .toSet();
    final supportEntries = eligible
        .where((e) => supportIds.contains(e.id))
        .toList();

    var months = <String>{};
    for (final e in supportEntries) {
      months.add('${e.createdAt.year}-${e.createdAt.month}');
    }

    final recentCutoff = DateTime.now().subtract(const Duration(days: 30));
    final recentSupport = supportEntries
        .where((e) => !e.createdAt.isBefore(recentCutoff))
        .length;
    final recentShare = supportEntries.isEmpty
        ? 0
        : ((recentSupport / supportEntries.length) * 100).round();

    final themeKey = explanation.relatedThemes.isNotEmpty
        ? explanation.relatedThemes.first.themeKey
        : null;
    final keywords = themeKey != null
        ? ArchiveInterpretationEngine._themeKeywords[themeKey] ?? [themeKey]
        : const <String>[];

    final priorWindow = eligible
        .where((e) => e.createdAt.isBefore(recentCutoff))
        .toList();
    final recentWindow = eligible
        .where((e) => !e.createdAt.isBefore(recentCutoff))
        .toList();

    return _EvidenceStats(
      supportingCount: explanation.supportingEvidence.length,
      contradictingCount: explanation.contradictingEvidence.length,
      monthSpan: months.length,
      recentSharePercent: recentShare,
      confidenceMentions: _countHits(
        eligible,
        ArchiveInterpretationEngine._themeKeywords['confidence']!,
      ),
      uncertaintyMentions: _countHits(
        eligible,
        ArchiveInterpretationEngine._themeKeywords['uncertainty']!,
      ),
      workMentions: _countHits(
        eligible,
        ArchiveInterpretationEngine._themeKeywords['work']!,
      ),
      relationshipMentions: _countHits(
        eligible,
        ArchiveInterpretationEngine._themeKeywords['relationship']!,
      ),
      recentThemeMentions: keywords.isEmpty
          ? 0
          : _countHits(recentWindow, keywords),
      priorThemeMentions: keywords.isEmpty
          ? 0
          : _countHits(priorWindow, keywords),
      recentRelationshipMentions: _countHits(
        recentWindow,
        ArchiveInterpretationEngine._themeKeywords['relationship']!,
      ),
      priorRelationshipMentions: _countHits(
        priorWindow,
        ArchiveInterpretationEngine._themeKeywords['relationship']!,
      ),
      independenceSignals: _countHits(eligible, const [
        'trust myself',
        'on my own',
        'independent',
        'self-trust',
      ]),
    );
  }

  static int _countHits(List<JournalEntry> entries, List<String> keywords) {
    var n = 0;
    for (final e in entries) {
      final blob = '${e.transcript} ${e.reflection.exactLanguagePattern}'
          .toLowerCase();
      if (keywords.any(blob.contains)) n++;
    }
    return n;
  }
}
