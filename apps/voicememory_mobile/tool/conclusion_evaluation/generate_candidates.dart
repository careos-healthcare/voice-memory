/// Runs the real ArchiveMe conclusion pipeline over synthetic evaluation
/// fixtures and writes one candidate record per case.
///
/// Nothing in here re-implements the engine. Every decision recorded below
/// comes from production code:
///   * [AuditablePersonalChangeEngine.areRelated] for pairing,
///   * [AuditablePersonalChangeEngine.buildEarlyComparison] for emission,
///   * [SemanticConclusionGate.assess] for entailment,
///   * [ExplainableConclusionRenderGate.visible] for the render decision,
///   * [ExplainableConclusionValidator] for exact-evidence checks.
///
/// Run from `apps/voicememory_mobile`:
///   dart run tool/conclusion_evaluation/generate_candidates.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:voicememory_mobile/features/explainable_conclusion/auditable_personal_change_engine.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/change_dimensions.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/semantic_conclusion_gate.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

const defaultFixtureDirectory = 'tool/conclusion_evaluation/fixtures';
const defaultCandidateOutput = 'build/conclusion_evaluation/candidates.json';

/// Statement used to probe a case that should conclude nothing.
///
/// Every word is framing vocabulary, so the probe carries no content of its
/// own and any rejection it draws belongs to the evidence, not the wording.
const neutralChangeProbe = 'These saved moments changed.';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final fixtureDirectory = Directory(options.fixtures);
  if (!fixtureDirectory.existsSync()) {
    stderr.writeln('Fixture directory not found: ${options.fixtures}');
    stderr.writeln('Run this from apps/voicememory_mobile.');
    exitCode = 2;
    return;
  }

  final cases = loadFixtureCases(fixtureDirectory);
  final records = runHarness(cases);
  final payload = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'fixtureDirectory': options.fixtures,
    'caseCount': records.length,
    'dataProvenance': 'synthetic',
    'records': records,
  };

  final output = File(options.output);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
  );

  final emitted = records
      .where((record) => (record['actual'] as Map)['emitted'] == true)
      .length;
  stdout.writeln(
    'Loaded ${records.length} synthetic cases from '
    '${options.fixtures}',
  );
  stdout.writeln('Conclusions emitted by the engine: $emitted');
  stdout.writeln('Candidates written to ${options.output}');
}

/// Every fixture case in [directory], ordered by file then declaration.
List<Map<String, dynamic>> loadFixtureCases(Directory directory) {
  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final cases = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final file in files) {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map || decoded['cases'] is! List) {
      throw FormatException('${file.path} has no `cases` array.');
    }
    for (final entry in decoded['cases'] as List) {
      if (entry is! Map) {
        throw FormatException('${file.path} contains a non-object case.');
      }
      final fixture = Map<String, dynamic>.from(entry);
      _requireFields(fixture, file.path);
      final caseId = fixture['caseId'] as String;
      if (!seen.add(caseId)) {
        throw FormatException('Duplicate caseId "$caseId" in ${file.path}.');
      }
      cases.add(fixture);
    }
  }
  return cases;
}

const _requiredFields = {
  'caseId',
  'entryA',
  'entryB',
  'relatedExpected',
  'expectedKind',
  'expectedChangedDimensions',
  'supportedConclusion',
  'prohibitedConclusions',
  'expectedSuppressionReason',
  'sourceDomain',
  'difficulty',
  'humanLabelStatus',
};

void _requireFields(Map<String, dynamic> fixture, String path) {
  for (final field in _requiredFields) {
    if (!fixture.containsKey(field)) {
      throw FormatException('Case in $path is missing "$field".');
    }
  }
}

List<Map<String, dynamic>> runHarness(List<Map<String, dynamic>> cases) =>
    cases.map(evaluateCase).toList(growable: false);

Map<String, dynamic> evaluateCase(Map<String, dynamic> fixture) {
  final first = _FixtureEntry.fromJson(fixture['entryA']);
  final rawSecond = fixture['entryB'];
  final second = rawSecond == null ? null : _FixtureEntry.fromJson(rawSecond);

  final ordered = second == null
      ? [first]
      : (second.capturedAt.isBefore(first.capturedAt)
            ? [second, first]
            : [first, second]);
  final then = ordered.first;
  final now = ordered.last;
  final isPair = second != null;

  final canonicalTranscripts = {
    for (final entry in ordered) entry.id: entry.transcript,
  };
  final deletedIds = {
    for (final entry in ordered)
      if (entry.deleted) entry.id,
  };
  final generatedIds = {
    for (final entry in ordered)
      if (entry.modelGenerated) entry.id,
  };
  final threadIds = <String, String?>{
    for (final entry in ordered) entry.id: entry.threadId,
  };
  final userCorrectedFraming = ordered.any(
    (entry) => entry.framingCorrectedByUser,
  );

  final journalEntries = ordered
      .map((entry) => entry.toJournalEntry())
      .toList(growable: false);

  final relatedByEngine =
      isPair &&
      AuditablePersonalChangeEngine.areRelated(
        then.toJournalEntry(),
        now.toJournalEntry(),
      );
  final ranked = AuditablePersonalChangeEngine.buildEarlyComparison(
    entries: journalEntries,
  );

  final readerDimensions = isPair
      ? ChangeDimensionReader.compare(
          before: then.transcript.trim(),
          after: now.transcript.trim(),
        )
      : const ChangeDimensions.empty();
  final dimensions = ranked?.dimensions ?? readerDimensions;

  final expectedKind = fixture['expectedKind'] as String;
  final supported = fixture['supportedConclusion'] as String?;
  final probeKind = _probeKind(expectedKind);

  final supportedProbe = _probe(
    statement: supported ?? neutralChangeProbe,
    kind: probeKind,
    then: then,
    now: isPair ? now : then,
    isPair: isPair,
    canonicalTranscripts: canonicalTranscripts,
    deletedIds: deletedIds,
    generatedIds: generatedIds,
    threadIds: threadIds,
    userCorrectedFraming: userCorrectedFraming,
  );

  final prohibited = <Map<String, dynamic>>[];
  for (final raw in (fixture['prohibitedConclusions'] as List)) {
    final item = Map<String, dynamic>.from(raw as Map);
    final violation = item['violation'] as String;
    // An overclaim is by definition a claim of a stronger kind than the
    // evidence supports, so it is probed as the kind it pretends to be.
    final kind = violation == 'overclaim'
        ? ExplainableInsightKind.change
        : probeKind;
    final result = _probe(
      statement: item['statement'] as String,
      kind: kind,
      then: then,
      now: isPair ? now : then,
      isPair: isPair,
      canonicalTranscripts: canonicalTranscripts,
      deletedIds: deletedIds,
      generatedIds: generatedIds,
      threadIds: threadIds,
      userCorrectedFraming: userCorrectedFraming,
    );
    prohibited.add({
      'statement': item['statement'],
      'violation': violation,
      'probedAsKind': kind.name,
      ...result,
    });
  }

  final emittedConclusion = ranked?.conclusion.value;
  final emittedQuotes = emittedConclusion == null
      ? const <String>[]
      : emittedConclusion.evidence
            .map((citation) => citation.quote)
            .toList(growable: false);

  return {
    'caseId': fixture['caseId'],
    'sourceDomain': fixture['sourceDomain'],
    'difficulty': fixture['difficulty'],
    'humanLabelStatus': fixture['humanLabelStatus'],
    'isPair': isPair,
    'expected': {
      'relatedExpected': fixture['relatedExpected'],
      'expectedKind': expectedKind,
      'expectedChangedDimensions': fixture['expectedChangedDimensions'],
      'expectedSuppressionReason': fixture['expectedSuppressionReason'],
      'supportedConclusion': supported,
      'usedNeutralProbe': supported == null,
    },
    'actual': {
      'relatedByEngine': relatedByEngine,
      'emitted': emittedConclusion != null,
      'emittedKind': emittedConclusion?.kind.name,
      'emittedStatement': emittedConclusion?.statement,
      'emittedConfidence': emittedConclusion?.confidence,
      'dimensionSource': ranked != null ? 'engine' : 'reader',
      'detectedChangedDimensions': _describe(dimensions.changed),
      'comparableDimensions': _describe(dimensions.movements),
      'conflictingEvidence': dimensions.isConflicting,
      'sharedSubjectMarkers': (dimensions.sharedSubjectMarkers.toList()
        ..sort()),
      'supportedProbe': supportedProbe,
      'prohibitedProbes': prohibited,
      'exactEvidenceValid': emittedConclusion == null
          ? null
          : _exactEvidenceHolds(emittedConclusion, canonicalTranscripts),
      'evidenceBlockReasons': emittedConclusion == null
          ? const <String>[]
          : ExplainableConclusionValidator.validate(
              emittedConclusion,
              canonicalTranscripts: canonicalTranscripts,
            ).blockReasons.map((reason) => reason.name).toList(growable: false),
      'genericOutput': emittedConclusion == null
          ? null
          : isGenericStatement(emittedConclusion.statement, emittedQuotes),
    },
  };
}

ExplainableInsightKind _probeKind(String expectedKind) =>
    switch (expectedKind) {
      'observation' => ExplainableInsightKind.observation,
      'repeat' => ExplainableInsightKind.pattern,
      _ => ExplainableInsightKind.change,
    };

Map<String, dynamic> _probe({
  required String statement,
  required ExplainableInsightKind kind,
  required _FixtureEntry then,
  required _FixtureEntry now,
  required bool isPair,
  required Map<String, String> canonicalTranscripts,
  required Set<String> deletedIds,
  required Set<String> generatedIds,
  required Map<String, String?> threadIds,
  required bool userCorrectedFraming,
}) {
  final comparative = kind != ExplainableInsightKind.observation;
  final evidence = comparative
      ? [
          then.citation(
            comparative
                ? EvidenceTemporalRole.then
                : EvidenceTemporalRole.single,
          ),
          now.citation(
            comparative
                ? EvidenceTemporalRole.now
                : EvidenceTemporalRole.single,
          ),
        ]
      : [then.citation(EvidenceTemporalRole.single)];
  final cap = ExplainableConclusionValidator.evidenceConfidenceCap(evidence);
  final generatedAt = _latestCapture(evidence).add(const Duration(days: 1));

  final conclusion = ExplainableConclusion(
    id: 'probe_${then.id}_${now.id}_${kind.name}',
    statement: statement,
    confidence: cap <= 0 ? 1 : cap,
    reasoning: const ['Synthetic evaluation probe over the fixture evidence.'],
    uncertaintyNote:
        'Synthetic evaluation probe. This is not a claim shown to any user.',
    evidence: evidence,
    alternatives: const [
      ExplainableAlternative(
        statement: 'The wording may reflect these two moments only.',
        rationale: 'Two synthetic moments cannot establish a lasting change.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'conclusion_evaluation_harness',
      generatedAt: generatedAt,
      schemaVersion: ExplainableConclusion.schemaVersion,
      sourceRevision: 'conclusion_evaluation_v1',
    ),
    kind: kind,
  );

  final assessment = SemanticConclusionGate.assess(
    conclusion: conclusion,
    canonicalTranscripts: canonicalTranscripts,
    deletedEntryIds: deletedIds,
    generatedTextEntryIds: generatedIds,
    entryThreadIds: threadIds,
    userCorrectedFraming: userCorrectedFraming,
  );
  final rendered = ExplainableConclusionRenderGate.visible(
    conclusion,
    canonicalTranscripts: canonicalTranscripts,
  );

  return {
    'accepted': assessment.isEntailed,
    'rejections': assessment.rejections
        .map((rejection) => rejection.name)
        .toList(growable: false),
    'derivedConfidence': assessment.signals.value,
    'renderGateVisible': rendered != null,
    'renderBlockReasons': ExplainableConclusionValidator.validate(
      conclusion,
      canonicalTranscripts: canonicalTranscripts,
    ).blockReasons.map((reason) => reason.name).toList(growable: false),
  };
}

DateTime _latestCapture(List<TranscriptEvidenceCitation> evidence) => evidence
    .map((citation) => citation.sourceCapturedAt!)
    .reduce((a, b) => a.isAfter(b) ? a : b);

List<String> _describe(List<DimensionMovement> movements) {
  final described =
      movements
          .map(
            (movement) =>
                '${movement.dimension.name}:${movement.direction.name}',
          )
          .toList()
        ..sort();
  return described;
}

/// Every citation on [conclusion] resolves to the exact span it claims.
bool _exactEvidenceHolds(
  ExplainableConclusion conclusion,
  Map<String, String> canonicalTranscripts,
) {
  for (final citation in conclusion.evidence) {
    final transcript = canonicalTranscripts[citation.entryId];
    if (transcript == null) return false;
    if (citation.startUtf16 < 0 ||
        citation.endUtf16 <= citation.startUtf16 ||
        citation.endUtf16 > transcript.length) {
      return false;
    }
    if (transcript.substring(citation.startUtf16, citation.endUtf16) !=
        citation.quote) {
      return false;
    }
  }
  return conclusion.evidence.isNotEmpty;
}

final RegExp _genericOpening = RegExp(
  r'^(?:this (?:may|might|could) (?:be|mean)|something (?:may|might)|'
  r'you may be experiencing|there (?:may|might) be|a possible pattern|'
  r'things (?:may|might))',
  caseSensitive: false,
);

/// A statement is generic when it opens with a stock hedge, or when it shares
/// no content word with the words it cites.
bool isGenericStatement(String statement, Iterable<String> quotes) {
  if (_genericOpening.hasMatch(statement.trim())) return true;
  final evidence = <String>{
    for (final quote in quotes) ..._statementTokens(quote),
  };
  if (evidence.isEmpty) return false;
  return _statementTokens(statement).intersection(evidence).isEmpty;
}

final RegExp _word = RegExp(r"[a-z0-9']+");

Set<String> _statementTokens(String value) => _word
    .allMatches(value.toLowerCase())
    .map((match) => match.group(0)!)
    .where((token) => token.length >= 4 && !_framingWords.contains(token))
    .toSet();

/// Words that frame a reading without naming anything specific to it.
const _framingWords = {
  'across',
  'again',
  'also',
  'appears',
  'between',
  'change',
  'changed',
  'different',
  'earlier',
  'evidence',
  'have',
  'later',
  'looks',
  'moment',
  'moments',
  'more',
  'moved',
  'pattern',
  'possible',
  'repeat',
  'repeated',
  'saved',
  'shifted',
  'similar',
  'some',
  'something',
  'that',
  'these',
  'they',
  'thing',
  'things',
  'this',
  'those',
  'what',
  'with',
  'your',
};

class _FixtureEntry {
  _FixtureEntry({
    required this.id,
    required this.transcript,
    required this.capturedAt,
    required this.threadId,
    required this.captureContextTag,
    required this.deleted,
    required this.modelGenerated,
    required this.framingCorrectedByUser,
  });

  factory _FixtureEntry.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value! as Map);
    final runtime = json['runtime'] == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(json['runtime'] as Map);
    return _FixtureEntry(
      id: json['id'] as String,
      transcript: json['transcript'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String).toUtc(),
      threadId: json['threadId'] as String?,
      captureContextTag: json['captureContextTag'] as String?,
      deleted: runtime['deleted'] == true,
      modelGenerated: runtime['modelGenerated'] == true,
      framingCorrectedByUser: runtime['framingCorrectedByUser'] == true,
    );
  }

  final String id;
  final String transcript;
  final DateTime capturedAt;
  final String? threadId;
  final String? captureContextTag;
  final bool deleted;
  final bool modelGenerated;
  final bool framingCorrectedByUser;

  String get quote => transcript.trim();

  JournalEntry toJournalEntry() => JournalEntry(
    id: id,
    createdAt: capturedAt,
    transcript: transcript,
    durationSeconds: 20,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    archiveThreadId: threadId,
    captureContextTag: captureContextTag,
    deletedAt: deleted ? capturedAt.add(const Duration(hours: 1)) : null,
  );

  TranscriptEvidenceCitation citation(EvidenceTemporalRole temporalRole) {
    final start = transcript.indexOf(quote);
    return TranscriptEvidenceCitation(
      entryId: id,
      quote: quote,
      startUtf16: start,
      endUtf16: start + quote.length,
      role: TranscriptEvidenceRole.supporting,
      sourceCapturedAt: capturedAt,
      sourceType: EvidenceSourceType.text,
      temporalRole: temporalRole,
    );
  }
}

class _Options {
  const _Options({required this.fixtures, required this.output});

  factory _Options.parse(List<String> args) {
    var fixtures = defaultFixtureDirectory;
    var output = defaultCandidateOutput;
    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--fixtures' && index + 1 < args.length) {
        fixtures = args[++index];
      } else if (arg.startsWith('--fixtures=')) {
        fixtures = arg.substring('--fixtures='.length);
      } else if (arg == '--out' && index + 1 < args.length) {
        output = args[++index];
      } else if (arg.startsWith('--out=')) {
        output = arg.substring('--out='.length);
      }
    }
    return _Options(fixtures: fixtures, output: output);
  }

  final String fixtures;
  final String output;
}
