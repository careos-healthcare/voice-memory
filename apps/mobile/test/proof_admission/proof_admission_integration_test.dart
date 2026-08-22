import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_analytics.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_display_gate.dart';
import 'package:archiveme_mobile/features/proof_admission/verified_proof_view_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:archiveme_mobile/services/proof_analytics_guard.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/proof/proof_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _archive = ProofDisplayGate.defaultArchiveScope;
const String _owner = ProofDisplayGate.defaultOwnerScope;
const _otherArchive = 'archive-b';

const _firstTranscript =
    'I said yes to the extra project today before I checked my calendar.';
const _secondTranscript =
    'I said yes to covering the review before I checked my calendar again.';
const _thirdTranscript =
    'This morning I said yes to another ask before I checked my calendar.';

const _firstQuote =
    'yes to the extra project today before I checked my calendar';
const _secondQuote = 'yes to covering the review before I checked my calendar';
const _thirdQuote = 'yes to another ask before I checked my calendar';
const _shortThirdQuote = 'said yes';

/// The statement every one-moment scenario asserts, so correction memory keyed
/// on its framing applies across scenarios exactly as it would in the app.
const _observation = 'You said yes before checking your calendar.';

/// The same relationship said differently. Word order and filler change; the
/// semantic framing fingerprint does not.
const _paraphrasedObservation = 'Before checking your calendar, you said yes.';

const _preferredWording = 'I agree first and look at my week afterwards';

/// A source entry as the capture path builds it: the revision is the privacy
/// hash of the transcript, which is what [ProofDisplayGate.sourceFor] recomputes
/// at display time.
ProofSourceEntry _source({
  required String id,
  required String transcript,
  required DateTime createdAt,
  String archive = _archive,
  bool remoteProcessingConsented = true,
}) => ProofSourceEntry(
  entryId: id,
  archiveScope: archive,
  ownerScope: _owner,
  transcript: transcript,
  transcriptRevision: UserContentSafety.privacyHash(transcript),
  createdAt: createdAt,
  sourceType: ProofSourceType.userVoiceTranscript,
  remoteProcessingConsented: remoteProcessingConsented,
);

final ProofSourceEntry _first = _source(
  id: 'entry-1',
  transcript: _firstTranscript,
  createdAt: DateTime.utc(2026, 7),
);
final ProofSourceEntry _second = _source(
  id: 'entry-2',
  transcript: _secondTranscript,
  createdAt: DateTime.utc(2026, 7, 2),
);
final ProofSourceEntry _third = _source(
  id: 'entry-3',
  transcript: _thirdTranscript,
  createdAt: DateTime.utc(2026, 7, 10),
);
final ProofSourceEntry _firstInOtherArchive = _source(
  id: 'entry-1',
  transcript: _firstTranscript,
  createdAt: DateTime.utc(2026, 7),
  archive: _otherArchive,
);

Map<String, dynamic> _cite(
  ProofSourceEntry source, {
  required String quote,
  String role = 'support',
}) => {
  'sourceEntryId': source.entryId,
  'quote': quote,
  'role': role,
  'sourceRevision': source.transcriptRevision,
};

Map<String, dynamic> _claim({
  required String id,
  required String kind,
  required String text,
  required List<Map<String, dynamic>> citations,
}) => {'id': id, 'kind': kind, 'text': text, 'citations': citations};

RawModelResponse _raw({
  required String providerResponseId,
  required String observation,
  required List<Map<String, dynamic>> claims,
  String? tension,
}) => RawModelResponse(
  payload: {
    'reflection': {
      'mood': 'neutral',
      'emotionalIntensity': 2,
      'recurringThemes': ['capacity'],
      'exactLanguagePattern': _firstQuote,
      'concreteObservation': observation,
      'repeatedSignal': 'The same sequence appeared more than once.',
      'nextSmallAction': 'Check the calendar before answering.',
      'tensionOrContradiction': ?tension,
      'confidence': 0.9,
      'claims': claims,
    },
  },
  receivedAt: DateTime.utc(2026, 7, 11),
  providerResponseId: providerResponseId,
);

/// Deterministic stand-in for the model provider.
///
/// Every answer comes from a fixed table, so one scenario name always yields a
/// byte-identical payload. Nothing in this class opens a socket, reads a clock,
/// or touches an analytics sink: the pipeline under test is real, the model is
/// not.
class _FakeProofProvider {
  _FakeProofProvider(this._canned);

  final Map<String, RawModelResponse> _canned;

  /// Every scenario asked for, so a test can prove a refused admission did not
  /// quietly retry against the provider.
  final List<String> requested = <String>[];

  RawModelResponse responseFor(String scenario) {
    final canned = _canned[scenario];
    if (canned == null) {
      throw StateError('fake provider has no canned answer for "$scenario"');
    }
    requested.add(scenario);
    return canned;
  }
}

final _provider = _FakeProofProvider({
  // One moment, and a repeat the model asserted on that same moment.
  'first_moment': _raw(
    providerResponseId: 'candidate-first-moment',
    observation: _observation,
    claims: [
      _claim(
        id: 'main',
        kind: 'main_observation',
        text: _observation,
        citations: [_cite(_first, quote: _firstQuote)],
      ),
      _claim(
        id: 'repeat',
        kind: 'repeated',
        text: 'You do this every time.',
        citations: [_cite(_first, quote: _firstQuote)],
      ),
    ],
  ),
  // The same claim once a second distinct moment exists.
  'repeat_two_moments': _raw(
    providerResponseId: 'candidate-repeat-two-moments',
    observation: _observation,
    claims: [
      _claim(
        id: 'main',
        kind: 'main_observation',
        text: _observation,
        citations: [_cite(_second, quote: _secondQuote)],
      ),
      _claim(
        id: 'repeat',
        kind: 'repeated',
        text: 'You do this every time.',
        citations: [
          _cite(_first, quote: _firstQuote),
          _cite(_second, quote: _secondQuote),
        ],
      ),
    ],
  ),
  // A quote the model invented: nothing like it is in the transcript.
  'unquoted_citation': _raw(
    providerResponseId: 'candidate-unquoted-citation',
    observation: _observation,
    claims: [
      _claim(
        id: 'main',
        kind: 'main_observation',
        text: _observation,
        citations: [
          _cite(_first, quote: 'I turned the extra project down flat'),
        ],
      ),
    ],
  ),
  'single_moment': _raw(
    providerResponseId: 'candidate-single-moment',
    observation: _observation,
    claims: [
      _claim(
        id: 'main',
        kind: 'main_observation',
        text: _observation,
        citations: [_cite(_first, quote: _firstQuote)],
      ),
    ],
  ),
  'two_moment_observation': _raw(
    providerResponseId: 'candidate-two-moment-observation',
    observation: _observation,
    claims: [
      _claim(
        id: 'main',
        kind: 'main_observation',
        text: _observation,
        citations: [
          _cite(_first, quote: _firstQuote),
          _cite(_second, quote: _secondQuote),
        ],
      ),
    ],
  ),
  'paraphrased_observation': _raw(
    providerResponseId: 'candidate-paraphrased-observation',
    observation: _paraphrasedObservation,
    claims: [
      _claim(
        id: 'main',
        kind: 'main_observation',
        text: _paraphrasedObservation,
        citations: [_cite(_first, quote: _firstQuote)],
      ),
    ],
  ),
  'three_moments': _raw(
    providerResponseId: 'candidate-three-moments',
    observation: _observation,
    claims: [
      _claim(
        id: 'main',
        kind: 'main_observation',
        text: _observation,
        citations: [_cite(_third, quote: _shortThirdQuote)],
      ),
      _claim(
        id: 'repeat',
        kind: 'repeated',
        text: 'The same sequence appeared in three moments.',
        citations: [
          _cite(_first, quote: _firstQuote),
          _cite(_second, quote: _secondQuote),
          _cite(_third, quote: _thirdQuote),
        ],
      ),
    ],
  ),
  'contradicted_observation': _raw(
    providerResponseId: 'candidate-contradicted-observation',
    observation: _observation,
    tension: 'One moment runs the other way.',
    claims: [
      _claim(
        id: 'main',
        kind: 'main_observation',
        text: _observation,
        citations: [
          _cite(_first, quote: _firstQuote),
          _cite(_second, quote: _secondQuote, role: 'contradiction'),
        ],
      ),
    ],
  ),
  'other_archive_moment': _raw(
    providerResponseId: 'candidate-other-archive-moment',
    observation: _observation,
    claims: [
      _claim(
        id: 'main',
        kind: 'main_observation',
        text: _observation,
        citations: [_cite(_firstInOtherArchive, quote: _firstQuote)],
      ),
    ],
  ),
});

CanonicalProofAdmissionService _service({
  required DateTime now,
  bool withCorrectionMemory = false,
}) => CanonicalProofAdmissionService(
  clock: () => now,
  correctionPolicy: withCorrectionMemory
      ? ArchiveCorrectionStore.instance
      : const NoProofCorrectionAdmissionPolicy(),
);

ProofAdmissionResult _admit(
  String scenario, {
  required List<ProofSourceEntry> sources,
  required ProofSourceEntry primary,
  required DateTime now,
  bool withCorrectionMemory = false,
  String archive = _archive,
}) => _service(now: now, withCorrectionMemory: withCorrectionMemory).admit(
  raw: _provider.responseFor(scenario),
  sourceEntries: sources,
  activeArchiveScope: archive,
  activeOwnerScope: _owner,
  primarySourceEntryId: primary.entryId,
);

VerifiedProof _admitted(
  String scenario, {
  required List<ProofSourceEntry> sources,
  required ProofSourceEntry primary,
  required DateTime now,
  bool withCorrectionMemory = false,
  String archive = _archive,
}) {
  final result = _admit(
    scenario,
    sources: sources,
    primary: primary,
    now: now,
    withCorrectionMemory: withCorrectionMemory,
    archive: archive,
  );
  expect(
    result,
    isA<ProofAdmitted>(),
    reason: 'scenario "$scenario" was expected to be admitted',
  );
  return (result as ProofAdmitted).proof;
}

/// The saved journal entry for a source, as the archive would hold it.
JournalEntry _entry(
  ProofSourceEntry source, {
  required VerifiedProof proof,
  String? transcript,
}) => JournalEntry(
  id: source.entryId,
  createdAt: source.createdAt,
  transcript: transcript ?? source.transcript,
  durationSeconds: 12,
  reflection: proof.reflection,
  verifiedProof: proof,
);

/// Points the singleton correction store at a real file, exactly as startup
/// does, so persistence in these tests is the production path.
Future<void> _configureStore(String prefsPath) async {
  ArchiveCorrectionStore.resetForTest();
  ArchiveCorrectionStore.instance.configure(
    await MobilePrefsStore.open(prefsPath),
  );
  await ArchiveCorrectionStore.instance.ensureLoaded();
}

Future<String> _freshPrefsPath() async {
  final directory = await Directory.systemTemp.createTemp('vm_proof_e2e_');
  addTearDown(() => directory.deleteSync(recursive: true));
  return '${directory.path}/prefs.json';
}

Set<ProofClaimKind> _kinds(VerifiedProof proof) =>
    proof.claims.map((claim) => claim.kind).toSet();

void main() {
  setUp(() {
    ArchiveCorrectionStore.resetForTest();
    ProofAnalyticsGuard.resetForTest();
    _provider.requested.clear();
  });

  tearDown(ArchiveCorrectionStore.resetForTest);

  test('a first saved entry yields only a narrow current observation', () {
    final proof = _admitted(
      'first_moment',
      sources: [_first],
      primary: _first,
      now: DateTime.utc(2026, 7, 2),
    );

    expect(_kinds(proof), {ProofClaimKind.mainObservation});
    expect(_kinds(proof), isNot(contains(ProofClaimKind.repeated)));
    expect(
      proof.qualityReceipt.unsupportedClaims,
      contains(ProofClaimKind.repeated),
    );
    expect(proof.qualityReceipt.proofType, ProofType.currentObservation);
    expect(proof.qualityReceipt.frequency.distinctMoments, 1);
    expect(proof.qualityReceipt.frequency.established, isFalse);
    expect(
      proof.qualityReceipt.missingEvidence,
      contains(MissingEvidenceReason.needsAnotherDistinctSource),
    );
    // The model asserted a repeat in prose too; that prose is dropped with it.
    expect(proof.reflection.repeatedSignal, isEmpty);
  });

  test('a repeat is verified only once a second distinct moment exists', () {
    final oneMoment = _admitted(
      'first_moment',
      sources: [_first],
      primary: _first,
      now: DateTime.utc(2026, 7, 2),
    );
    expect(_kinds(oneMoment), isNot(contains(ProofClaimKind.repeated)));
    expect(oneMoment.qualityReceipt.frequency.established, isFalse);

    final twoMoments = _admitted(
      'repeat_two_moments',
      sources: [_first, _second],
      primary: _second,
      now: DateTime.utc(2026, 7, 3),
    );

    expect(_kinds(twoMoments), contains(ProofClaimKind.repeated));
    expect(twoMoments.qualityReceipt.proofType, ProofType.repeatedSignal);
    expect(twoMoments.qualityReceipt.frequency.distinctMoments, 2);
    expect(twoMoments.qualityReceipt.frequency.established, isTrue);
    expect(
      twoMoments.qualityReceipt.missingEvidence,
      isNot(contains(MissingEvidenceReason.needsAnotherDistinctSource)),
    );
    expect(twoMoments.reflection.repeatedSignal, isNotEmpty);

    final threeMoments = _admitted(
      'three_moments',
      sources: [_first, _second, _third],
      primary: _third,
      now: DateTime.utc(2026, 7, 11),
    );
    expect(_kinds(threeMoments), contains(ProofClaimKind.repeated));
    expect(threeMoments.qualityReceipt.frequency.distinctMoments, 3);
  });

  test('a citation whose quote is not in the transcript is refused and nothing '
      'is stored', () {
    final result = _admit(
      'unquoted_citation',
      sources: [_first],
      primary: _first,
      now: DateTime.utc(2026, 7, 2),
    );

    expect(result, isA<ProofNotAdmitted>());
    expect(result.outcome, ProofAdmissionOutcome.invalidEvidence);
    expect(
      (result as ProofNotAdmitted).reason,
      'quote_span_invalid_or_ambiguous',
    );

    // The moment is still saved; the proof is simply absent from it, so the
    // display gate has nothing to show and the invented quote never lands in
    // durable storage.
    final saved = JournalEntry.fromJson({
      'id': _first.entryId,
      'createdAt': _first.createdAt.toIso8601String(),
      'transcript': _first.transcript,
      'durationSeconds': 12,
      'reflection': const <String, dynamic>{},
    });
    expect(saved.verifiedProof, isNull);
    expect(const ProofDisplayGate().latestVerified([saved]), isNull);
    expect(
      jsonEncode(saved.toJson()),
      isNot(contains('I turned the extra project down flat')),
    );
    expect(ArchiveCorrectionStore.instance.records, isEmpty);
    expect(_provider.requested, ['unquoted_citation']);
  });

  test('editing the transcript after admission withdraws the proof at display '
      'time', () {
    const gate = ProofDisplayGate();
    final proof = _admitted(
      'single_moment',
      sources: [_first],
      primary: _first,
      now: DateTime.utc(2026, 7, 2),
    );
    final saved = _entry(_first, proof: proof);

    expect(
      gate.revalidate(proof: proof, entries: [saved]).outcome,
      ProofAdmissionOutcome.admitted,
    );
    expect(gate.viewFor(proof: proof, entries: [saved]), isNotNull);
    expect(gate.latestVerified([saved]), isNotNull);

    final edited = _entry(
      _first,
      proof: proof,
      transcript: 'I turned the extra project down before lunch.',
    );

    final result = gate.revalidate(proof: proof, entries: [edited]);
    expect(result.outcome, ProofAdmissionOutcome.stale);
    expect(
      (result as ProofNotAdmitted).reason,
      'proof_source_revision_changed',
    );
    expect(gate.viewFor(proof: proof, entries: [edited]), isNull);
    expect(gate.latestVerified([edited]), isNull);
  });

  test(
    'exactly right raises later confidence but never manufactures a repeat',
    () async {
      await _configureStore(await _freshPrefsPath());
      final before = _admitted(
        'single_moment',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );

      await ArchiveCorrectionStore.instance.recordForProof(
        proof: before,
        choice: ArchiveCorrectionChoice.exactlyRight,
        sourceSurface: 'proof_detail_sheet',
        now: DateTime.utc(2026, 7, 2, 12),
      );

      final after = _admitted(
        'first_moment',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );

      expect(
        ArchiveCorrectionStore.instance.positiveHistory(
          before.semanticFramingFingerprint,
        ),
        1,
      );
      expect(
        after.confidenceBand.index,
        greaterThan(before.confidenceBand.index),
      );
      // The hard threshold is evidence, not approval: one moment is still one.
      expect(_kinds(after), isNot(contains(ProofClaimKind.repeated)));
      expect(after.qualityReceipt.frequency.distinctMoments, 1);
      expect(after.qualityReceipt.frequency.established, isFalse);
      expect(
        after.qualityReceipt.missingEvidence,
        contains(MissingEvidenceReason.needsAnotherDistinctSource),
      );
    },
  );

  test(
    'partly right caps the confidence band on a later equivalent proof',
    () async {
      await _configureStore(await _freshPrefsPath());
      final before = _admitted(
        'two_moment_observation',
        sources: [_first, _second],
        primary: _second,
        now: DateTime.utc(2026, 7, 3),
        withCorrectionMemory: true,
      );
      expect(before.confidenceBand, ProofConfidenceBand.high);

      await ArchiveCorrectionStore.instance.recordForProof(
        proof: before,
        choice: ArchiveCorrectionChoice.partlyRight,
        sourceSurface: 'proof_detail_sheet',
        now: DateTime.utc(2026, 7, 3, 12),
      );

      final after = _admitted(
        'two_moment_observation',
        sources: [_first, _second],
        primary: _second,
        now: DateTime.utc(2026, 7, 3),
        withCorrectionMemory: true,
      );

      expect(after.confidenceBand, ProofConfidenceBand.medium);
      expect(after.qualityReceipt.confidenceBand, ProofConfidenceBand.medium);
      expect(
        VerifiedProofViewModel.fromVerifiedProof(after).confidenceLabel,
        'Medium confidence',
      );
      // Capping is not suppression: the same evidence is still on the card.
      expect(after.claims.single.evidence, hasLength(2));
    },
  );

  test(
    'wrong suppresses a trivial paraphrase of the rejected framing',
    () async {
      await _configureStore(await _freshPrefsPath());
      final rejected = _admitted(
        'single_moment',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );

      await ArchiveCorrectionStore.instance.recordForProof(
        proof: rejected,
        choice: ArchiveCorrectionChoice.wrong,
        sourceSurface: 'proof_detail_sheet',
        now: DateTime.utc(2026, 7, 2, 12),
      );

      final paraphrase = _admit(
        'paraphrased_observation',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );

      expect(paraphrase.outcome, ProofAdmissionOutcome.correctionSuppressed);
      expect(
        (paraphrase as ProofNotAdmitted).reason,
        'framing_rejected_as_wrong',
      );
    },
  );

  test(
    "wrong wording keeps the evidence and shows the user's preferred label",
    () async {
      await _configureStore(await _freshPrefsPath());
      final before = _admitted(
        'single_moment',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );

      await ArchiveCorrectionStore.instance.recordForProof(
        proof: before,
        choice: ArchiveCorrectionChoice.wrongWording,
        sourceSurface: 'proof_detail_sheet',
        preferredWording: _preferredWording,
        now: DateTime.utc(2026, 7, 2, 12),
      );

      final after = _admitted(
        'single_moment',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );
      final view = VerifiedProofViewModel.fromVerifiedProof(after);

      expect(after.qualityReceipt.userConfirmedWording, _preferredWording);
      expect(view.statement, _preferredWording);
      expect(_kinds(after), {ProofClaimKind.mainObservation});
      expect(after.claims.single.evidence.single.sourceEntryId, _first.entryId);
      expect(view.supportingEvidence.single.quote, _firstQuote);
    },
  );

  test(
    'wrong evidence removes the citation and drops a proof that needed it',
    () async {
      await _configureStore(await _freshPrefsPath());
      final before = _admitted(
        'two_moment_observation',
        sources: [_first, _second],
        primary: _second,
        now: DateTime.utc(2026, 7, 3),
        withCorrectionMemory: true,
      );
      expect(before.claims.single.evidence.map((item) => item.sourceEntryId), [
        _first.entryId,
        _second.entryId,
      ]);

      await ArchiveCorrectionStore.instance.recordForProof(
        proof: before,
        choice: ArchiveCorrectionChoice.wrongEvidence,
        sourceSurface: 'proof_detail_sheet',
        disputedEvidenceRefs: [_first.entryId],
        now: DateTime.utc(2026, 7, 3, 12),
      );

      // The disputed moment is dropped; the undisputed one still holds it up.
      final trimmed = _admitted(
        'two_moment_observation',
        sources: [_first, _second],
        primary: _second,
        now: DateTime.utc(2026, 7, 3),
        withCorrectionMemory: true,
      );
      expect(trimmed.claims.single.evidence.map((item) => item.sourceEntryId), [
        _second.entryId,
      ]);

      // With only the disputed moment behind it there is nothing left to show.
      final after = _admit(
        'single_moment',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );

      expect(after.outcome, ProofAdmissionOutcome.insufficientEvidence);
      expect(
        (after as ProofNotAdmitted).reason,
        'remaining_evidence_insufficient_after_correction',
      );
    },
  );

  test(
    'ignore forever still suppresses after the store is reloaded from disk',
    () async {
      final prefsPath = await _freshPrefsPath();
      await _configureStore(prefsPath);
      final proof = _admitted(
        'single_moment',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );
      await ArchiveCorrectionStore.instance.recordForProof(
        proof: proof,
        choice: ArchiveCorrectionChoice.ignoreForever,
        sourceSurface: 'proof_detail_sheet',
        now: DateTime.utc(2026, 7, 2, 12),
      );

      // Restart: the singleton is emptied and rebuilt from the same file.
      await _configureStore(prefsPath);

      expect(ArchiveCorrectionStore.instance.records, hasLength(1));
      expect(
        ArchiveCorrectionStore.instance.records.single.choice,
        ArchiveCorrectionChoice.ignoreForever,
      );

      final after = _admit(
        'single_moment',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );
      expect(after.outcome, ProofAdmissionOutcome.correctionSuppressed);
      expect((after as ProofNotAdmitted).reason, 'ignore_forever');
    },
  );

  test('contradicting evidence stays visible in the receipt', () {
    const gate = ProofDisplayGate();
    final proof = _admitted(
      'contradicted_observation',
      sources: [_first, _second],
      primary: _first,
      now: DateTime.utc(2026, 7, 3),
    );
    final view = gate.viewFor(
      proof: proof,
      entries: [
        _entry(_first, proof: proof),
        _entry(_second, proof: proof),
      ],
    )!;

    expect(proof.qualityReceipt.contradictions, hasLength(1));
    expect(proof.qualityReceipt.contradictions.single.quote, _secondQuote);
    expect(proof.qualityReceipt.proofType, ProofType.unresolved);
    expect(
      proof.qualityReceipt.missingEvidence,
      contains(MissingEvidenceReason.needsContradictionResolution),
    );
    expect(proof.reflection.tensionOrContradiction, isNotNull);
    expect(view.contradictions.single.quote, _secondQuote);
    expect(
      view.missingEvidenceLines,
      contains('Something you said contradicts this, and it is not resolved.'),
    );
  });

  testWidgets(
    'the detail view shows frequency, trend, occurrences and what is missing',
    (tester) async {
      const gate = ProofDisplayGate();
      final proof = _admitted(
        'three_moments',
        sources: [_first, _second, _third],
        primary: _third,
        now: DateTime.utc(2026, 7, 11),
      );
      final view = gate.viewFor(
        proof: proof,
        entries: [
          _entry(_first, proof: proof),
          _entry(_second, proof: proof),
          _entry(_third, proof: proof),
        ],
      )!;

      expect(view.frequencyLine, isNotNull);
      expect(view.trendLine, isNotNull);
      expect(view.hasOccurrenceRange, isTrue);
      expect(view.firstOccurrence, DateTime.utc(2026, 7));
      expect(view.lastOccurrence, DateTime.utc(2026, 7, 10));
      expect(view.missingEvidenceLines, isNotEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProofDetailSheet(proof: view)),
        ),
      );

      expect(
        find.byKey(const Key('proof_detail_frequency_line')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('proof_detail_trend')), findsOneWidget);
      expect(
        find.byKey(const Key('proof_detail_first_occurrence')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('proof_detail_last_occurrence')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('proof_detail_missing_0')), findsOneWidget);
      expect(find.text('First seen 1 Jul 2026.'), findsOneWidget);
      expect(find.text('Most recently seen 10 Jul 2026.'), findsOneWidget);
    },
  );

  test(
    'a correction in one archive cannot suppress a proof in another archive',
    () async {
      await _configureStore(await _freshPrefsPath());
      final proof = _admitted(
        'single_moment',
        sources: [_first],
        primary: _first,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
      );
      await ArchiveCorrectionStore.instance.recordForProof(
        proof: proof,
        choice: ArchiveCorrectionChoice.ignoreForever,
        sourceSurface: 'proof_detail_sheet',
        now: DateTime.utc(2026, 7, 2, 12),
      );
      expect(
        _admit(
          'single_moment',
          sources: [_first],
          primary: _first,
          now: DateTime.utc(2026, 7, 2),
          withCorrectionMemory: true,
        ).outcome,
        ProofAdmissionOutcome.correctionSuppressed,
      );

      final elsewhere = _admit(
        'other_archive_moment',
        sources: [_firstInOtherArchive],
        primary: _firstInOtherArchive,
        now: DateTime.utc(2026, 7, 2),
        withCorrectionMemory: true,
        archive: _otherArchive,
      );

      expect(elsewhere.outcome, ProofAdmissionOutcome.admitted);
      expect((elsewhere as ProofAdmitted).proof.archiveScope, _otherArchive);
    },
  );

  test('a full admission emits no content bearing analytics', () {
    final proof = _admitted(
      'single_moment',
      sources: [_first],
      primary: _first,
      now: DateTime.utc(2026, 7, 2),
    );

    final payload = ProofAdmissionAnalytics.payload(
      result: ProofAdmitted(proof),
      distinctSourceCount: 1,
      contradictionCount: 0,
      duration: const Duration(milliseconds: 12),
    );
    final safe = ProofAnalyticsGuard.sanitize(
      ProofAdmissionAnalytics.eventName,
      payload,
    );

    // Nothing had to be stripped, which means nothing content-bearing was
    // offered in the first place.
    expect(safe, payload);
    expect(ProofAnalyticsGuard.drops, isEmpty);
    expect(ProofAnalyticsGuard.droppedCount, 0);

    final encoded = jsonEncode(safe);
    for (final content in <String>[
      _firstTranscript,
      _firstQuote,
      _observation,
      _first.entryId,
      _archive,
      _owner,
      proof.proofId,
      proof.proofFingerprint,
      proof.semanticFramingFingerprint,
      proof.wordingFingerprint,
      proof.sourceRevisionFingerprint,
    ]) {
      expect(encoded, isNot(contains(content)));
    }
    for (final forbidden in <String>[
      'transcript',
      'quote',
      'statement',
      'entry_id',
      'archive_id',
      'fingerprint',
      'score',
    ]) {
      expect(safe.keys, isNot(contains(forbidden)));
    }
    expect(safe['admission_result'], 'admitted');
    expect(safe['source_count_band'], 'one');
    expect(safe['contradiction_count_band'], 'none');
    expect(safe['duration_band'], 'under_50ms');
  });
}