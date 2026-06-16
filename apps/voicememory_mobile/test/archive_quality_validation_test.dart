import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_analyst/archive_analyst_engine.dart';
import 'package:voicememory_mobile/features/archive_analyst/topical_counter_evidence.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_pack_builder.dart';
import 'package:voicememory_mobile/features/archive_analyst/archive_analyst_models.dart';
import 'package:voicememory_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:voicememory_mobile/features/archive_deep_dive/archive_deep_dive_engine.dart';
import 'package:voicememory_mobile/features/archive_deep_dive/archive_deep_dive_models.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:voicememory_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:voicememory_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:voicememory_mobile/features/archive_v1/archive_v1_builder.dart';
import 'package:voicememory_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_service.dart';
import 'package:voicememory_mobile/features/belief_lifecycle/belief_lifecycle_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

import 'support/archive_quality_personas.dart';

/// Runs Archive V1 (Theory, Lifecycle, Change Feed), Deep Dive, and Analyst.
/// Output: `tool/output/archive_quality_raw.json` (for ARCHIVE_V2_VALIDATION.md).
void main() {
  test('archive quality validation — capture engine outputs', () async {
    final scenarios = <Map<String, dynamic>>[];
    final allBeliefStatements = <String>[];

    for (final persona in ArchiveQualityPersona.values) {
      for (final size in [50, 100, 200]) {
        final dir = await Directory.systemTemp.createTemp(
          'aq_${persona.name}_$size',
        );
        final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
        final evolution = BeliefEvolutionService.fromPrefs(prefs);
        final entries = buildPersonaArchive(persona, count: size);
        final baseline = _simulatedReviewBaseline(entries);

        final v1 = await const ArchiveV1Builder().build(
          entries: entries,
          evolutionService: evolution,
          baseline: baseline,
        );
        final dive = const ArchiveDeepDiveEngine().build(v1: v1);
        final analyst = await const ArchiveAnalystEngine().build(
          entries: entries,
          evolutionService: evolution,
        );

        for (final b in analyst.currentBeliefs) {
          allBeliefStatements.add(b.statement.trim().toLowerCase());
        }

        final pack = ArchiveSynthesisPackBuilder.build(
          view: v1,
          monthKey: '2026-05',
          milestonesReached: const {},
        );
        final packTheory =
            (pack['theory'] as Map<String, dynamic>?)?['statement'] as String?;

        scenarios.add({
          'persona': persona.name,
          'reflectionCount': size,
          'eligibleCount': analyst.eligibleReflectionCount,
          'analystLevel': analyst.level.toString().split('.').last,
          'hasAnalystReport': analyst.hasReport,
          'baselineSimulated': baseline != null,
          'baselineReviewAt': baseline?.timestamp,
          'v1': _serializeV1(v1),
          'theory': _serializeTheory(v1.theory),
          'lifecycle': _serializeLifecycle(v1.lifecycle),
          'changeFeed': _serializeChangeFeed(v1.changeFeed),
          'deepDive': _serializeDeepDive(dive),
          'analyst': _serializeAnalyst(analyst),
          'metrics': _metrics(analyst, dive, v1, packTheory, persona.name),
          'unifiedPrimary': {
            'rankingPrimary': v1.theoryRanking?.primaryStatement,
            'theoryStatement': v1.theory?.statement,
            'packTheoryStatement': packTheory,
          },
        });
      }
    }

    final crossPersonaDupes = _duplicateStatements(allBeliefStatements);

    final payload = {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'validationVersion': 2,
      'scenarioCount': scenarios.length,
      'crossPersonaDuplicateBeliefs': crossPersonaDupes,
      'scenarios': scenarios,
    };

    final outDir = Directory('tool/output');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final relevance = _counterEvidenceRelevance(scenarios);
    payload['counterEvidenceRelevance'] = relevance;

    final outFile = File('tool/output/archive_quality_raw.json');
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    expect(scenarios.length, 15);
    expect(outFile.existsSync(), isTrue);
    expect(
      relevance['relevanceRate'] as double,
      greaterThan(0.85),
      reason:
          'Topical counter-evidence relevance must exceed 85% '
          '(was ${relevance['relevant']}/${relevance['total']})',
    );

    final primaryFailures = <String>[];
    for (final s in scenarios) {
      final m = s['metrics'] as Map<String, dynamic>;
      if (m['theoryMatchesPrimary'] != true) {
        primaryFailures.add(
          '${s['persona']}@${s['reflectionCount']}: hero≠analyst',
        );
      }
      if (m['theoryZeroEvidenceHero'] == true) {
        primaryFailures.add(
          '${s['persona']}@${s['reflectionCount']}: 0-ev hero',
        );
      }
      if (m['relationshipWorkHero'] == true) {
        primaryFailures.add(
          '${s['persona']}@${s['reflectionCount']}: work hero',
        );
      }
      if (m['unifiedSurfaceMismatch'] == true) {
        primaryFailures.add(
          '${s['persona']}@${s['reflectionCount']}: surface mismatch',
        );
      }
      if (m['heroEqualsTopRankedTheory'] != true &&
          s['theory']?['present'] == true) {
        primaryFailures.add(
          '${s['persona']}@${s['reflectionCount']}: hero≠top ranked',
        );
      }
    }
    expect(
      primaryFailures,
      isEmpty,
      reason: 'Unified primary theory:\n${primaryFailures.join('\n')}',
    );

    final pollutionFailures = <String>[];
    for (final s in scenarios) {
      final m = s['metrics'] as Map<String, dynamic>;
      final label = '${s['persona']}@${s['reflectionCount']}';
      if ((m['visibleZeroConfidenceCount'] as int) > 0) {
        pollutionFailures.add('$label: ${m['zeroConfidenceListed']}');
      }
      if ((m['visibleZeroEvidenceCount'] as int) > 0) {
        pollutionFailures.add('$label: zero-ev ${m['zeroEvidenceListed']}');
      }
      if ((m['visibleTraitTemplateCount'] as int) > 0) {
        pollutionFailures.add('$label: traits ${m['traitTemplatesListed']}');
      }
    }
    expect(
      pollutionFailures,
      isEmpty,
      reason:
          'Trait pollution in visible UI rows:\n${pollutionFailures.join('\n')}',
    );
  });
}

void _appendTraitTemplate(String statement, List<String> traits) {
  final lower = statement.toLowerCase();
  if (lower.startsWith('you focus on') ||
      lower.startsWith('you express confidence') ||
      lower.startsWith('you avoid conflict') ||
      lower.contains('working belief is forming')) {
    traits.add(statement);
  }
}

Map<String, List<String>> _visibleTraitPollution(ArchiveAnalystReport analyst) {
  final zeroConf = <String>[];
  final zeroEv = <String>[];
  final traits = <String>[];

  void check(String statement, int confidence, int evidence) {
    if (confidence == 0) zeroConf.add(statement);
    if (evidence < 3) zeroEv.add(statement);
    _appendTraitTemplate(statement, traits);
  }

  for (final b in analyst.currentBeliefs) {
    check(b.statement, b.confidencePercent, b.evidenceCount);
  }
  for (final b in analyst.emergingBeliefs) {
    if (b.confidencePercent == 0) zeroConf.add(b.statement);
    _appendTraitTemplate(b.statement, traits);
  }
  for (final b in analyst.fadingBeliefs) {
    if (b.confidencePercent == 0) zeroConf.add(b.statement);
    _appendTraitTemplate(b.statement, traits);
  }
  for (final b in analyst.competingBeliefs) {
    if (b.confidencePercent == 0) zeroConf.add(b.statement);
    if (b.confidencePercent < 15) zeroConf.add(b.statement);
    _appendTraitTemplate(b.statement, traits);
  }

  return {
    'zeroConfidence': zeroConf,
    'zeroEvidence': zeroEv,
    'traitTemplates': traits,
  };
}

Map<String, dynamic> _counterEvidenceRelevance(
  List<Map<String, dynamic>> scenarios,
) {
  const topical = TopicalCounterEvidence();
  var total = 0;
  var relevant = 0;

  for (final s in scenarios) {
    final analyst = s['analyst'] as Map<String, dynamic>;
    final debates = (analyst['debates'] as List).cast<Map<String, dynamic>>();
    for (final d in debates) {
      final belief = (d['beliefStatement'] as String?)?.trim() ?? '';
      final quote = (d['firstCounterQuote'] as String?)?.trim() ?? '';
      if (belief.isEmpty || quote.isEmpty) continue;
      total++;
      if (topical.isRelevantCounterQuote(
        beliefText: belief,
        counterQuote: quote,
      )) {
        relevant++;
      }
    }
  }

  final rate = total == 0 ? 0.0 : relevant / total;
  return {
    'relevant': relevant,
    'total': total,
    'relevanceRate': rate,
    'targetMet': rate > 0.85,
  };
}

/// Mid-archive visit (~45% through eligible timeline) for Change Feed deltas.
ArchiveStateSnapshot? _simulatedReviewBaseline(List<JournalEntry> entries) {
  final eligible = archiveEligibleEvidenceEntries(entries);
  if (eligible.length < 20) return null;
  final idx = (eligible.length * 0.45).floor().clamp(8, eligible.length - 8);
  final pivot = eligible[idx];
  final obs = pivot.reflection?.concreteObservation.trim();
  return ArchiveStateSnapshot(
    belief: (obs != null && obs.isNotEmpty) ? obs : pivot.transcript,
    confidence: 55,
    reputation: 'developing',
    evidenceCount: idx + 1,
    lifeAreas: const [],
    timestamp: pivot.createdAt.toUtc().toIso8601String(),
  );
}

Map<String, dynamic> _serializeV1(ArchiveV1View v1) {
  return {
    'hasMinimumEvidence': v1.hasMinimumEvidence,
    'belief': v1.belief == null
        ? null
        : {
            'statement': v1.belief!.statement,
            'confidencePercent': v1.belief!.confidencePercent,
            'evidenceCount': v1.belief!.evidenceCount,
          },
    'thenNow': v1.thenNow == null
        ? null
        : {
            'thenBelief': v1.thenNow!.thenBelief,
            'nowBelief': v1.thenNow!.nowBelief,
            'hasDistinctEvolution': v1.thenNow!.hasDistinctEvolution,
          },
    'contradictions': v1.contradictions
        .map(
          (c) => {
            'youSay': c.youSay,
            'but': c.but,
            'confidenceScore': c.confidenceScore,
          },
        )
        .toList(),
    'blindSpots': v1.blindSpots
        .map(
          (b) => {
            'headline': b.headline,
            'observation': b.observation,
            'confidence': b.confidence,
          },
        )
        .toList(),
    'evolutionBlockCount': v1.evolutionTimeline.blocks.length,
  };
}

Map<String, dynamic> _serializeTheory(ArchiveCurrentTheory? theory) {
  if (theory == null) {
    return {'present': false};
  }
  return {
    'present': true,
    'statement': theory.statement,
    'confidencePercent': theory.confidencePercent,
    'evidenceCount': theory.evidenceCount,
    'counterEvidenceCount': theory.counterEvidenceCount,
    'isConfident': theory.isConfident,
    'missingEvidenceMessage': theory.missingEvidenceMessage,
    'strengthenLineCount': theory.strengthenEvidenceLines.length,
    'strengthenLines': theory.strengthenEvidenceLines.take(3).toList(),
  };
}

Map<String, dynamic> _serializeLifecycle(BeliefLifecycleView lifecycle) {
  final current = lifecycle.current;
  return {
    'hasContent': lifecycle.hasContent,
    'current': current == null
        ? null
        : {
            'statement': current.statement,
            'status': current.status.name,
            'eventCount': current.events.length,
            'events': current.events
                .map((e) => {'phase': e.phase.name, 'summary': e.summary})
                .take(5)
                .toList(),
          },
    'retiredCount': lifecycle.retired.length,
    'retired': lifecycle.retired
        .map(
          (r) => {
            'statement': r.statement,
            'status': r.status.name,
            'eventCount': r.events.length,
            'isNoLongerDetected': r.isNoLongerDetected,
          },
        )
        .take(4)
        .toList(),
  };
}

Map<String, dynamic> _serializeChangeFeed(ArchiveChangeFeedView feed) {
  return {
    'hasBaseline': feed.hasBaseline,
    'hasChanges': feed.hasChanges,
    'newReflectionCount': feed.newReflectionCount,
    'totalChangeCount': feed.totalChangeCount,
    'beliefsStrengthened': feed.beliefsStrengthened
        .map(
          (b) => {
            'statement': b.statement,
            'confidenceBefore': b.confidenceBefore,
            'confidenceNow': b.confidenceNow,
            'evidenceCount': b.evidenceCount,
          },
        )
        .toList(),
    'beliefsWeakened': feed.beliefsWeakened
        .map(
          (b) => {
            'statement': b.statement,
            'confidenceBefore': b.confidenceBefore,
            'confidenceNow': b.confidenceNow,
          },
        )
        .toList(),
    'contradictionsAppeared': feed.contradictionsAppeared.length,
    'contradictionsResolved': feed.contradictionsResolved.length,
    'themesIncreasing': feed.themesIncreasing
        .map(
          (t) => {
            'label': t.label,
            'mentionSeries': t.mentionSeries,
            'mentionsAtReview': t.mentionsAtReview,
            'mentionsNow': t.mentionsNow,
          },
        )
        .toList(),
    'themesDecreasing': feed.themesDecreasing
        .map(
          (t) => {
            'label': t.label,
            'mentionSeries': t.mentionSeries,
            'mentionsAtReview': t.mentionsAtReview,
            'mentionsNow': t.mentionsNow,
          },
        )
        .toList(),
    'emptyMessage': feed.emptyMessage,
  };
}

Map<String, dynamic>? _serializeDeepDive(ArchiveDeepDiveView? dive) {
  if (dive == null) return null;
  return {
    'beliefStatement': dive.beliefStatement,
    'confidencePercent': dive.confidencePercent,
    'whySummary': dive.why.summaryLines,
    'whyEvidenceCount': dive.why.evidenceCount,
    'historyThen': dive.history.thenSnapshot.beliefText,
    'historyNow': dive.history.nowSnapshot.beliefText,
    'patternThemeCount': dive.patterns.relatedThemes.length,
    'patternContradictionCount': dive.patterns.connectedContradictions.length,
    'counterForCount': dive.counterEvidence.forExcerpts.length,
    'counterAgainstCount':
        dive.counterEvidence.againstExcerpts.length +
        dive.counterEvidence.againstSummaries.length,
    'inquiryCount': dive.inquiryQuestions.length,
    'timelineEventCount':
        dive.timeline.keyRecordings.length +
        dive.timeline.evolutionEvents.length,
  };
}

Map<String, dynamic> _serializeAnalyst(ArchiveAnalystReport report) {
  return {
    'level': report.level.toString().split('.').last,
    'eligibleReflectionCount': report.eligibleReflectionCount,
    'currentBeliefs': report.currentBeliefs
        .map(
          (b) => {
            'statement': b.statement,
            'confidencePercent': b.confidencePercent,
            'evidenceCount': b.evidenceCount,
            'counterEvidenceCount': b.counterEvidenceCount,
            'isPrimary': b.isPrimary,
          },
        )
        .toList(),
    'emergingBeliefs': report.emergingBeliefs
        .map(
          (b) => {
            'statement': b.statement,
            'confidencePercent': b.confidencePercent,
            'trendLabel': b.trendLabel,
            'mentionSeries': b.mentionSeries,
          },
        )
        .toList(),
    'fadingBeliefs': report.fadingBeliefs
        .map(
          (b) => {
            'statement': b.statement,
            'confidencePercent': b.confidencePercent,
            'trendLabel': b.trendLabel,
            'mentionSeries': b.mentionSeries,
          },
        )
        .toList(),
    'contradictions': report.contradictions
        .map(
          (c) => {
            'youSay': c.youSay,
            'but': c.but,
            'confidenceScore': c.confidenceScore,
          },
        )
        .toList(),
    'blindSpots': report.blindSpots
        .map((b) => {'headline': b.headline, 'observation': b.observation})
        .toList(),
    'competingBeliefs': report.competingBeliefs
        .map(
          (c) => {
            'statement': c.statement,
            'confidencePercent': c.confidencePercent,
            'isPrimary': c.isPrimary,
          },
        )
        .toList(),
    'debates': report.debates
        .map(
          (d) => {
            'beliefStatement': d.beliefStatement,
            'confidencePercent': d.confidencePercent,
            'evidenceForCount': d.evidenceForCount,
            'evidenceAgainstCount': d.evidenceAgainstCount,
            'supportingExcerptCount': d.supportingExcerpts.length,
            'counterExcerptCount': d.counterExcerpts.length,
            'timelineNotes': d.timelineNotes,
            'firstSupportQuote': d.supportingExcerpts.isEmpty
                ? null
                : d.supportingExcerpts.first.quote,
            'firstCounterQuote': d.counterExcerpts.isEmpty
                ? null
                : d.counterExcerpts.first.quote,
          },
        )
        .toList(),
    'evidenceSummary': {
      'dateSpanLabel': report.evidenceSummary.dateSpanLabel,
      'uniqueBeliefCandidates': report.evidenceSummary.uniqueBeliefCandidates,
      'contradictionCount': report.evidenceSummary.contradictionCount,
      'blindSpotCount': report.evidenceSummary.blindSpotCount,
    },
  };
}

Map<String, dynamic> _metrics(
  ArchiveAnalystReport analyst,
  ArchiveDeepDiveView? dive,
  ArchiveV1View v1,
  String? packTheoryStatement,
  String personaName,
) {
  final genericPhrases = <String>[
    'still gathering evidence',
    'helping others but rarely mention your own needs',
    'future plans but rarely celebrate',
    'repeated concern may be forming',
    'you may keep returning to',
    'you focus on',
    'you express confidence',
    'you avoid conflict',
    'forming from reflections',
  ];

  final statements = <String>[
    ...analyst.currentBeliefs.map((b) => b.statement),
    ...analyst.emergingBeliefs.map((b) => b.statement),
    ...analyst.fadingBeliefs.map((b) => b.statement),
  ];

  final genericHits = <String>[];
  for (final s in statements) {
    final lower = s.toLowerCase();
    for (final p in genericPhrases) {
      if (lower.contains(p)) genericHits.add(p);
    }
  }

  final weakConfidence = analyst.currentBeliefs
      .where((b) => b.confidencePercent >= 75 && b.evidenceCount < 5)
      .map(
        (b) =>
            '${b.statement} (${b.confidencePercent}% / ${b.evidenceCount} ev)',
      )
      .toList();

  final visiblePollution = _visibleTraitPollution(analyst);
  final zeroConfidenceListed =
      visiblePollution['zeroConfidence'] as List<String>;
  final zeroEvidenceListed = visiblePollution['zeroEvidence'] as List<String>;
  final traitTemplatesListed =
      visiblePollution['traitTemplates'] as List<String>;

  final highCounterLowSupport = analyst.currentBeliefs
      .where((b) => b.counterEvidenceCount > b.evidenceCount)
      .map((b) => b.statement)
      .toList();

  final debatesMissingExcerpts = analyst.debates
      .where(
        (d) =>
            d.supportingExcerpts.isEmpty ||
            (d.evidenceAgainstCount > 0 && d.counterExcerpts.isEmpty),
      )
      .map((d) => d.beliefStatement)
      .toList();

  final theory = v1.theory;
  final lifecycle = v1.lifecycle;
  final feed = v1.changeFeed;

  final primaryStatement = analyst.currentBeliefs
      .where((b) => b.isPrimary)
      .map((b) => b.statement)
      .firstOrNull;

  final rankingPrimary = v1.theoryRanking?.primaryStatement?.trim();

  final theoryMatchesPrimary =
      theory != null &&
      primaryStatement != null &&
      theory.statement.trim() == primaryStatement.trim();

  final heroEqualsTopRanked =
      theory != null &&
      rankingPrimary != null &&
      theory.statement.trim() == rankingPrimary;

  final theoryZeroEvidenceHero = theory != null && theory.evidenceCount < 3;

  final relationshipWorkHero =
      personaName == 'relationshipFocused' &&
      theory != null &&
      theory.statement.toLowerCase().contains(
        'work delivery pressure dominates',
      );
  final lifecycleMatches =
      lifecycle.current?.statement.trim() == theory?.statement.trim();
  final diveMatches = dive?.beliefStatement.trim() == theory?.statement.trim();
  final packMatches = packTheoryStatement?.trim() == theory?.statement.trim();
  final unifiedSurfaceMismatch =
      theory != null &&
      (!theoryMatchesPrimary ||
          rankingPrimary != theory.statement.trim() ||
          lifecycleMatches == false ||
          diveMatches == false ||
          packMatches == false);

  final dominantAlsoFading = analyst.fadingBeliefs.any(
    (f) => analyst.currentBeliefs.any(
      (c) =>
          c.isPrimary &&
          c.statement.trim().toLowerCase() == f.statement.trim().toLowerCase(),
    ),
  );

  return {
    'genericPhraseHits': genericHits.toSet().toList(),
    'weakConfidenceHighScore': weakConfidence,
    'zeroConfidenceListed': zeroConfidenceListed,
    'zeroEvidenceListed': zeroEvidenceListed,
    'traitTemplatesListed': traitTemplatesListed,
    'visibleZeroConfidenceCount': zeroConfidenceListed.length,
    'visibleZeroEvidenceCount': zeroEvidenceListed.length,
    'visibleTraitTemplateCount': traitTemplatesListed.length,
    'counterExceedsSupport': highCounterLowSupport,
    'debatesMissingExcerpts': debatesMissingExcerpts,
    'deepDiveAvailable': dive != null,
    'emergingCount': analyst.emergingBeliefs.length,
    'fadingCount': analyst.fadingBeliefs.length,
    'competingEchoesPrimary':
        analyst.competingBeliefs.length > 1 &&
        analyst.competingBeliefs
            .skip(1)
            .every(
              (c) => c.statement == analyst.competingBeliefs.first.statement,
            ),
    'theoryPresent': theory != null,
    'theoryShowsCounterCount': (theory?.counterEvidenceCount ?? 0) > 0,
    'theoryLowConfidenceHonest': theory != null && !theory.isConfident,
    'theoryStrengthenLines': theory?.strengthenEvidenceLines.length ?? 0,
    'theoryMatchesPrimary': theoryMatchesPrimary,
    'heroEqualsTopRankedTheory': heroEqualsTopRanked,
    'theoryZeroEvidenceHero': theoryZeroEvidenceHero,
    'relationshipWorkHero': relationshipWorkHero,
    'unifiedSurfaceMismatch': unifiedSurfaceMismatch,
    'lifecycleMatchesTheory': lifecycleMatches,
    'deepDiveMatchesTheory': diveMatches,
    'synthesisMatchesTheory': packMatches,
    'lifecycleHasContent': lifecycle.hasContent,
    'lifecycleRetiredCount': lifecycle.retired.length,
    'lifecycleHasWeakeningOrDeath':
        lifecycle.retired.any(
          (r) =>
              r.status == BeliefLifecycleStatus.weakening ||
              r.status == BeliefLifecycleStatus.dormant ||
              r.status == BeliefLifecycleStatus.noLongerDetected,
        ) ||
        lifecycle.current?.status == BeliefLifecycleStatus.weakening,
    'changeFeedHasChanges': feed.hasChanges,
    'changeFeedTotalItems': feed.totalChangeCount,
    'dominantBeliefAlsoFading': dominantAlsoFading,
    'analystContradictionCount': analyst.contradictions.length,
    'v1ContradictionCount': v1.contradictions.length,
  };
}

List<String> _duplicateStatements(List<String> normalized) {
  final counts = <String, int>{};
  for (final s in normalized) {
    if (s.length < 20) continue;
    counts[s] = (counts[s] ?? 0) + 1;
  }
  return counts.entries
      .where((e) => e.value >= 3)
      .map((e) => '${e.key} (×${e.value})')
      .toList();
}
