import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/evidence_verifier.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';

void main() {
  const verifier = CanonicalEvidenceVerifier();
  const archive = 'archive-1';
  const owner = 'owner-1';
  const entryId = 'entry-1';
  final now = DateTime.utc(2026, 8, 1);

  ProofSourceEntry sourceFor(String transcript, {String revision = 'rev-1'}) {
    return ProofSourceEntry(
      entryId: entryId,
      archiveScope: archive,
      ownerScope: owner,
      transcript: transcript,
      transcriptRevision: revision,
      createdAt: now,
      sourceType: ProofSourceType.userVoiceTranscript,
      remoteProcessingConsented: true,
    );
  }

  EvidenceCitationDraft citation({
    required String quote,
    int? startUtf16,
    int? endUtf16,
    String sourceRevision = 'rev-1',
  }) {
    return EvidenceCitationDraft(
      sourceEntryId: entryId,
      quote: quote,
      role: ProofEvidenceRole.support,
      startUtf16: startUtf16,
      endUtf16: endUtf16,
      sourceRevision: sourceRevision,
    );
  }

  EvidenceVerificationResult verifySpan({
    required String transcript,
    required EvidenceCitationDraft draft,
    String revision = 'rev-1',
  }) {
    return verifier.verify(
      citations: [draft],
      sources: {entryId: sourceFor(transcript, revision: revision)},
      activeArchiveScope: archive,
      activeOwnerScope: owner,
      now: now,
    );
  }

  test('rejects negative UTF-16 offsets', () {
    final result = verifySpan(
      transcript: 'hello world',
      draft: citation(quote: 'hello', startUtf16: -1, endUtf16: 5),
    );
    expect(result.valid, isFalse);
    expect(result.reason, 'quote_span_invalid_or_ambiguous');
  });

  test('rejects reversed offsets', () {
    final result = verifySpan(
      transcript: 'hello world',
      draft: citation(quote: 'hello', startUtf16: 5, endUtf16: 2),
    );
    expect(result.valid, isFalse);
  });

  test('rejects offset beyond transcript length', () {
    final result = verifySpan(
      transcript: 'short',
      draft: citation(quote: 'missing', startUtf16: 0, endUtf16: 99),
    );
    expect(result.valid, isFalse);
  });

  test('rejects source revision mismatch', () {
    final result = verifySpan(
      transcript: 'hello',
      draft: citation(
        quote: 'hello',
        startUtf16: 0,
        endUtf16: 5,
        sourceRevision: 'rev-stale',
      ),
      revision: 'rev-live',
    );
    expect(result.valid, isFalse);
    expect(result.reason, 'source_revision_mismatch');
  });
}
