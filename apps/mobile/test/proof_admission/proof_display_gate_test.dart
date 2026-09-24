import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_display_gate.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:flutter_test/flutter_test.dart';

const _archive = 'local_archive_v1';
const _owner = 'local_owner_v1';
const _transcript = 'I said yes again before checking my calendar.';
const _quote = 'said yes again';

const _gate = ProofDisplayGate();

JournalEntry _entry({
  String id = 'entry-1',
  String transcript = _transcript,
  bool archived = false,
  VerifiedProof? proof,
}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 7),
  transcript: transcript,
  durationSeconds: 12,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: _quote,
    concreteObservation: 'You agreed before checking your calendar.',
    repeatedSignal: '',
  ),
  isArchived: archived,
  verifiedProof: proof,
);

/// Admits a real proof through the pipeline, so the gate is tested against
/// something the pipeline actually produced rather than a hand-built object
/// that might not be reachable.
VerifiedProof _admitted({
  String transcript = _transcript,
  String entryId = 'entry-1',
}) {
  final service = CanonicalProofAdmissionService(
    clock: () => DateTime.utc(2026, 7, 2),
  );
  final result = service.admit(
    raw: RawModelResponse(
      payload: {
        'reflection': {
          'mood': 'neutral',
          'emotionalIntensity': 2,
          'recurringThemes': const ['capacity'],
          'exactLanguagePattern': _quote,
          'concreteObservation': 'You agreed before checking your calendar.',
          'repeatedSignal': 'This always happens.',
          'nextSmallAction': 'Say no next time.',
        },
      },
      receivedAt: DateTime.utc(2026, 7, 2),
    ),
    sourceEntries: [
      ProofSourceEntry(
        entryId: entryId,
        archiveScope: _archive,
        ownerScope: _owner,
        transcript: transcript,
        transcriptRevision: UserContentSafety.privacyHash(transcript),
        createdAt: DateTime.utc(2026, 7),
        sourceType: ProofSourceType.userVoiceTranscript,
        remoteProcessingConsented: true,
      ),
    ],
    activeArchiveScope: _archive,
    activeOwnerScope: _owner,
    primarySourceEntryId: entryId,
  );
  expect(
    result,
    isA<ProofAdmitted>(),
    reason: 'the fixture itself must be admissible',
  );
  return (result as ProofAdmitted).proof;
}

void main() {
  group('proof display gate', () {
    test('an untouched proof still renders', () {
      final proof = _admitted();
      final entries = [_entry(proof: proof)];

      expect(
        _gate.revalidate(proof: proof, entries: entries),
        isA<ProofAdmitted>(),
      );
      expect(_gate.viewFor(proof: proof, entries: entries), isNotNull);
      expect(_gate.latestVerified(entries), isNotNull);
    });

    test('editing the quoted transcript withdraws the proof', () {
      final proof = _admitted();
      final entries = [
        _entry(
          proof: proof,
          transcript: 'I said no this time before checking my calendar.',
        ),
      ];

      final result = _gate.revalidate(proof: proof, entries: entries);

      expect(result, isA<ProofNotAdmitted>());
      expect(
        (result as ProofNotAdmitted).outcome,
        ProofAdmissionOutcome.stale,
        reason: 'the quote no longer exists in the transcript it came from',
      );
      expect(_gate.viewFor(proof: proof, entries: entries), isNull);
    });

    test('an edit that only adds text still withdraws the proof', () {
      // The span moves even when the quote survives, so the receipt no longer
      // describes the transcript it points at.
      final proof = _admitted();
      final entries = [_entry(proof: proof, transcript: 'Today $_transcript')];

      expect(_gate.viewFor(proof: proof, entries: entries), isNull);
    });

    test('archiving the source entry withdraws the proof', () {
      final proof = _admitted();
      final entries = [_entry(proof: proof, archived: true)];

      final result = _gate.revalidate(proof: proof, entries: entries);

      expect(
        (result as ProofNotAdmitted).outcome,
        ProofAdmissionOutcome.wrongArchive,
      );
      expect(_gate.viewFor(proof: proof, entries: entries), isNull);
    });

    test('deleting the source entry withdraws the proof', () {
      final proof = _admitted();

      final result = _gate.revalidate(proof: proof, entries: const []);

      expect(
        (result as ProofNotAdmitted).outcome,
        ProofAdmissionOutcome.sourceUnavailable,
      );
    });

    test('switching archive withdraws the proof', () {
      final proof = _admitted();
      final entries = [_entry(proof: proof)];
      const other = ProofDisplayGate(
        activeArchiveScope: 'another_archive',
        activeOwnerScope: 'another_owner',
      );

      final result = other.revalidate(proof: proof, entries: entries);

      expect(
        (result as ProofNotAdmitted).outcome,
        ProofAdmissionOutcome.wrongArchive,
      );
      expect(other.viewFor(proof: proof, entries: entries), isNull);
    });

    test('latestVerified falls silent rather than reaching further back', () {
      // The newest proof has gone stale. Showing the previous entry's proof
      // instead would present an older claim as though it were the one the
      // customer just saved.
      final older = _admitted();
      final newer = _admitted(entryId: 'entry-2');
      final entries = [
        _entry(proof: older),
        _entry(
          id: 'entry-2',
          proof: newer,
          transcript: 'Something else entirely.',
        ),
      ];

      expect(_gate.latestVerified(entries), isNull);
    });

    test('entries with no proof yield nothing rather than throwing', () {
      expect(_gate.latestVerified([_entry()]), isNull);
      expect(_gate.latestVerified(const []), isNull);
    });

    test('a warm cache still notices the edit', () {
      // The revision cache sits directly on this path, so a false hit would let
      // a proof survive an edit to the text it quotes — the exact failure the
      // gate exists to prevent. Reading the unedited entry first guarantees the
      // cache is populated before the edited one is checked.
      final proof = _admitted();
      final unchanged = [_entry(proof: proof)];
      expect(_gate.viewFor(proof: proof, entries: unchanged), isNotNull);

      final edited = [_entry(proof: proof, transcript: 'I said no this time.')];

      expect(_gate.viewFor(proof: proof, entries: edited), isNull);
      expect(
        _gate.viewFor(proof: proof, entries: unchanged),
        isNotNull,
        reason: 'and reverting the edit brings it back',
      );
    });

    test('the source view of an entry uses the live transcript revision', () {
      final source = _gate.sourceFor(_entry());

      expect(source.transcript, _transcript);
      expect(
        source.transcriptRevision,
        UserContentSafety.privacyHash(_transcript),
        reason: 'a revision derived any other way would not track edits',
      );
      expect(source.archiveScope, _archive);
      expect(source.archived, isFalse);
    });
  });
}
