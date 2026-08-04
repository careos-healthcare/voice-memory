import 'dart:convert';
import 'dart:io';

/// Reads archive_quality_raw.json and prints V2 grading summary.
void main() {
  final raw = File('tool/output/archive_quality_raw.json');
  if (!raw.existsSync()) {
    stderr.writeln(
      'Missing ${raw.path}. Run archive_quality_validation_test first.',
    );
    exit(1);
  }
  final j = jsonDecode(raw.readAsStringSync()) as Map<String, dynamic>;
  final scenarios = (j['scenarios'] as List).cast<Map<String, dynamic>>();

  final grades = <Map<String, dynamic>>[];
  var theoryTrustWins = 0;
  var theoryTrustTotal = 0;
  var lifecycleImpact = 0;
  var changeFeedValue = 0;
  var surpriseMoments = 0;
  var scenarioCount = 0;

  for (final s in scenarios) {
    final persona = s['persona'] as String;
    final size = s['reflectionCount'] as int;
    final eligible = s['eligibleCount'] as int;
    final theory = s['theory'] as Map<String, dynamic>;
    final lifecycle = s['lifecycle'] as Map<String, dynamic>;
    final feed = s['changeFeed'] as Map<String, dynamic>;
    final analyst = s['analyst'] as Map<String, dynamic>;
    final dive = s['deepDive'] as Map<String, dynamic>?;
    final metrics = s['metrics'] as Map<String, dynamic>;
    final v1 = s['v1'] as Map<String, dynamic>;

    scenarioCount++;
    final g = _gradeScenario(
      persona: persona,
      size: size,
      eligible: eligible,
      theory: theory,
      lifecycle: lifecycle,
      feed: feed,
      analyst: analyst,
      dive: dive,
      metrics: metrics,
      v1: v1,
    );
    grades.add(g);

    if (g['theoryMoreTrustworthy'] == true) theoryTrustWins++;
    if (theory['present'] == true) theoryTrustTotal++;
    if (g['lifecycleEmotionalImpact'] == true) lifecycleImpact++;
    if (g['changeFeedAddsValue'] == true) changeFeedValue++;
    if ((g['surpriseMoments'] as List).isNotEmpty) surpriseMoments++;

    stdout.writeln('=== $persona @ $size (eligible $eligible) ===');
    stdout.writeln('  Theory: ${g['theoryGrade']} — ${g['theoryNote']}');
    stdout.writeln(
      '  Lifecycle: ${g['lifecycleGrade']} — ${g['lifecycleNote']}',
    );
    stdout.writeln(
      '  ChangeFeed: ${g['changeFeedGrade']} — ${g['changeFeedNote']}',
    );
    stdout.writeln('  DeepDive: ${g['deepDiveGrade']} — ${g['deepDiveNote']}');
    stdout.writeln('  Analyst: ${g['analystGrade']} — ${g['analystNote']}');
    if ((g['surpriseMoments'] as List).isNotEmpty) {
      stdout.writeln('  SURPRISE: ${g['surpriseMoments']}');
    }
    if ((g['issues'] as List).isNotEmpty) {
      stdout.writeln('  ISSUES: ${g['issues']}');
    }
    stdout.writeln();
  }

  final summary = {
    'scenarioCount': scenarioCount,
    'theoryTrustRate': theoryTrustTotal == 0
        ? 0.0
        : theoryTrustWins / theoryTrustTotal,
    'lifecycleImpactRate': lifecycleImpact / scenarioCount,
    'changeFeedValueRate': changeFeedValue / scenarioCount,
    'scenariosWithSurprise': surpriseMoments,
    'grades': grades,
  };

  final out = File('tool/output/archive_v2_validation_summary.json');
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(summary));

  stdout.writeln('--- Aggregate ---');
  stdout.writeln(
    'Theory more trustworthy than Belief framing: $theoryTrustWins / $theoryTrustTotal scenarios',
  );
  stdout.writeln(
    'Lifecycle emotional impact: $lifecycleImpact / $scenarioCount',
  );
  stdout.writeln('Change Feed adds value: $changeFeedValue / $scenarioCount');
  stdout.writeln(
    'Scenarios with ≥1 surprise moment: $surpriseMoments / $scenarioCount',
  );
  stdout.writeln('Summary written: ${out.path}');
}

Map<String, dynamic> _gradeScenario({
  required String persona,
  required int size,
  required int eligible,
  required Map<String, dynamic> theory,
  required Map<String, dynamic> lifecycle,
  required Map<String, dynamic> feed,
  required Map<String, dynamic> analyst,
  required Map<String, dynamic>? dive,
  required Map<String, dynamic> metrics,
  required Map<String, dynamic> v1,
}) {
  final issues = <String>[];
  final surprises = <String>[];

  final generic = (metrics['genericPhraseHits'] as List).cast<String>();
  if (generic.isNotEmpty) issues.add('generic: $generic');
  if ((metrics['zeroConfidenceListed'] as List).isNotEmpty) {
    issues.add('0% beliefs listed');
  }
  if (metrics['dominantBeliefAlsoFading'] == true) {
    issues.add('primary belief also in fading');
  }
  if ((metrics['counterExceedsSupport'] as List).isNotEmpty) {
    issues.add('off-topic counter-evidence');
  }

  // Theory
  String theoryGrade = 'n/a';
  String theoryNote = 'no theory';
  var theoryMoreTrustworthy = false;
  if (theory['present'] == true) {
    final stmt = (theory['statement'] as String).toLowerCase();
    final conf = theory['confidencePercent'] as int;
    final counter = theory['counterEvidenceCount'] as int;
    final strengthen = theory['strengthenLineCount'] as int;
    final honest = theory['isConfident'] != true;

    theoryMoreTrustworthy = counter > 0 || strengthen >= 1 || honest;
    if (stmt.contains('you focus on') || conf == 0) {
      theoryGrade = 'obvious';
      theoryNote = 'trait or zero-confidence row';
    } else if (strengthen >= 2 && counter > 0 && conf >= 25 && conf <= 75) {
      theoryGrade = 'interesting';
      theoryNote = 'shows evidence + counters with calibrated confidence';
    } else if (conf < 30 && counter > 8) {
      theoryGrade = 'surprising';
      theoryNote = 'honest low confidence under counter-pressure';
      surprises.add(
        'Theory confidence dropped to $conf% with $counter counters',
      );
    } else if (conf >= 60 && strengthen >= 1) {
      theoryGrade = 'interesting';
      theoryNote = 'confident with quoted strengthen lines';
    } else {
      theoryGrade = 'obvious';
      theoryNote = 'restates dominant observation ($conf%)';
    }
  }

  // Lifecycle
  String lifecycleGrade = 'obvious';
  String lifecycleNote = 'empty or single-statement only';
  var lifecycleEmotionalImpact = false;
  final retired = (lifecycle['retired'] as List).length;
  final current = lifecycle['current'] as Map<String, dynamic>?;
  if (lifecycle['hasContent'] != true) {
    lifecycleGrade = 'obvious';
  } else if (retired >= 1 &&
      lifecycle['retired'].toString().contains('noLongerDetected')) {
    lifecycleGrade = 'surprising';
    lifecycleNote = 'retired belief with no-longer-detected status';
    lifecycleEmotionalImpact = true;
    surprises.add('Lifecycle: prior belief marked no longer detected');
  } else if (retired >= 1 ||
      (metrics['lifecycleHasWeakeningOrDeath'] == true)) {
    lifecycleGrade = 'interesting';
    lifecycleNote = 'retired/weakening beliefs with timeline events';
    lifecycleEmotionalImpact = retired >= 1;
  } else if (current != null && (current['eventCount'] as int) >= 2) {
    lifecycleGrade = 'interesting';
    lifecycleNote = 'phased events on active belief';
    lifecycleEmotionalImpact = true;
  }

  // Change Feed
  String changeFeedGrade = 'obvious';
  String changeFeedNote = 'no baseline or no changes';
  var changeFeedAddsValue = false;
  if (feed['hasBaseline'] != true) {
    changeFeedNote = 'no baseline in run (should not happen with sim)';
  } else if (feed['hasChanges'] != true) {
    changeFeedGrade = 'obvious';
    changeFeedNote = feed['emptyMessage'] ?? 'no deltas';
  } else {
    final total = feed['totalChangeCount'] as int;
    final themesUp = (feed['themesIncreasing'] as List).length;
    final themesDown = (feed['themesDecreasing'] as List).length;
    final weakened = (feed['beliefsWeakened'] as List).length;
    final strengthened = (feed['beliefsStrengthened'] as List).length;
    if (themesUp + themesDown >= 1 &&
        (feed['themesIncreasing'] as List).any((t) {
          final row = t as Map<String, dynamic>;
          final series = row['mentionSeries'] as List;
          return series.length >= 2 && series.last != series.first;
        })) {
      changeFeedGrade = 'interesting';
      changeFeedNote = 'monthly mention trend since simulated review';
      changeFeedAddsValue = true;
    }
    if (weakened >= 1 || strengthened >= 1) {
      changeFeedGrade = weakened >= 1 ? 'surprising' : 'interesting';
      changeFeedNote = 'belief confidence delta since review';
      changeFeedAddsValue = true;
      if (weakened >= 1) {
        surprises.add('Change feed: belief weakened since last review');
      }
    }
    if (total >= 3 && changeFeedGrade == 'obvious') {
      changeFeedGrade = 'interesting';
      changeFeedNote = '$total change rows';
      changeFeedAddsValue = true;
    }
  }

  // Deep Dive
  String deepDiveGrade = dive == null ? 'n/a' : 'obvious';
  String deepDiveNote = dive == null ? 'gated' : 'summary only';
  if (dive != null) {
    final against = dive['counterAgainstCount'] as int;
    final distinct =
        v1['thenNow'] != null &&
        (v1['thenNow'] as Map)['hasDistinctEvolution'] == true;
    if (against >= 2 && distinct) {
      deepDiveGrade = 'surprising';
      deepDiveNote = 'then/now shift with counter excerpts';
      surprises.add('Deep Dive: distinct then→now with counters');
    } else if (against >= 1) {
      deepDiveGrade = 'interesting';
      deepDiveNote = 'counter evidence present';
    }
    if (persona == 'relationshipFocused' &&
        (dive['beliefStatement'] as String).toLowerCase().contains('work')) {
      deepDiveGrade = 'obvious';
      deepDiveNote = 'misaligned — work belief not relationship arc';
      issues.add('deep dive wrong primary');
    }
  }

  // Analyst
  String analystGrade = 'obvious';
  String analystNote = 'thin or generic';
  final debates = (analyst['debates'] as List).length;
  final contradictions = (analyst['contradictions'] as List).length;
  final emerging = (analyst['emergingBeliefs'] as List).length;
  final competing = (analyst['competingBeliefs'] as List).length;
  final primary = (analyst['currentBeliefs'] as List).isNotEmpty
      ? ((analyst['currentBeliefs'] as List).first as Map)['statement']
      : '';

  if (debates >= 1) {
    final d0 = (analyst['debates'] as List).first as Map<String, dynamic>;
    if (d0['firstCounterQuote'] != null &&
        d0['counterExcerptCount'] as int > 0) {
      analystGrade = 'interesting';
      analystNote = 'debate with user counter-quote';
      if (persona == 'fitnessFocused' || persona == 'burnedOutEmployee') {
        analystGrade = 'surprising';
        surprises.add('Debate counter-quote reframes primary belief');
      }
    }
  }
  if (competing >= 2 && !_allSameMeaning(analyst['competingBeliefs'] as List)) {
    if (analystGrade == 'obvious') {
      analystGrade = 'interesting';
      analystNote = 'meaningfully different competing hypotheses';
    }
  }
  if (contradictions == 0 && persona != 'founder') {
    issues.add('seeded contradictions not in analyst');
  }
  if (primary.toString().toLowerCase().contains('you focus on')) {
    analystGrade = 'obvious';
    analystNote = 'identity trait primary';
  }
  if (emerging >= 1 && size >= 100) {
    if (analystGrade == 'obvious') {
      analystGrade = 'interesting';
      analystNote = 'emerging trend at L2+';
    }
  }

  return {
    'persona': persona,
    'size': size,
    'eligible': eligible,
    'theoryGrade': theoryGrade,
    'theoryNote': theoryNote,
    'lifecycleGrade': lifecycleGrade,
    'lifecycleNote': lifecycleNote,
    'changeFeedGrade': changeFeedGrade,
    'changeFeedNote': changeFeedNote,
    'deepDiveGrade': deepDiveGrade,
    'deepDiveNote': deepDiveNote,
    'analystGrade': analystGrade,
    'analystNote': analystNote,
    'theoryMoreTrustworthy': theoryMoreTrustworthy,
    'lifecycleEmotionalImpact': lifecycleEmotionalImpact,
    'changeFeedAddsValue': changeFeedAddsValue,
    'surpriseMoments': surprises,
    'issues': issues,
  };
}

bool _allSameMeaning(List competing) {
  if (competing.length < 2) return true;
  final a = (competing.first as Map)['statement'] as String;
  for (final c in competing.skip(1)) {
    final b = (c as Map)['statement'] as String;
    if (a.trim().toLowerCase() != b.trim().toLowerCase()) return false;
  }
  return true;
}
