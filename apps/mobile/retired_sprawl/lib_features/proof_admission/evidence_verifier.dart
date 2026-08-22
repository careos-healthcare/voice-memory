import 'dart:convert';

import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:crypto/crypto.dart';

class EvidenceVerificationResult {
  const EvidenceVerificationResult._({
    required this.valid,
    this.evidence = const [],
    this.outcome,
    this.reason,
  });

  factory EvidenceVerificationResult.valid(
    List<VerifiedEvidenceSnapshot> evidence,
  ) => EvidenceVerificationResult._(valid: true, evidence: evidence);

  factory EvidenceVerificationResult.invalid(
    ProofAdmissionOutcome outcome,
    String reason,
  ) => EvidenceVerificationResult._(
    valid: false,
    outcome: outcome,
    reason: reason,
  );

  final bool valid;
  final List<VerifiedEvidenceSnapshot> evidence;
  final ProofAdmissionOutcome? outcome;
  final String? reason;
}

class CanonicalEvidenceVerifier {
  const CanonicalEvidenceVerifier({this.verifierSchemaVersion = 1});

  /// The content fingerprint stored on an evidence snapshot.
  ///
  /// Display-time revalidation recomputes this and compares, so admission and
  /// revalidation must derive it identically or every stored proof would read
  /// as stale. It is one function for that reason.
  static String transcriptFingerprint(String transcript) =>
      sha256.convert(utf8.encode(transcript)).toString();

  final int verifierSchemaVersion;

  EvidenceVerificationResult verify({
    required List<EvidenceCitationDraft> citations,
    required Map<String, ProofSourceEntry> sources,
    required String activeArchiveScope,
    required String activeOwnerScope,
    required DateTime now,
  }) {
    final verified = <VerifiedEvidenceSnapshot>[];
    final seen = <String>{};

    for (final citation in citations) {
      final source = sources[citation.sourceEntryId];
      if (source == null) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.sourceUnavailable,
          'source_missing',
        );
      }
      if (source.archiveScope != activeArchiveScope ||
          source.ownerScope != activeOwnerScope) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.wrongArchive,
          'source_scope_mismatch',
        );
      }
      if (source.deleted || source.archived || !source.allowedByArchivePolicy) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.invalidEvidence,
          'source_not_eligible',
        );
      }
      if (source.sourceType == ProofSourceType.generatedPlaceholder) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.invalidEvidence,
          'generated_text_is_not_evidence',
        );
      }
      final transcript = source.transcript;
      final trimmed = transcript.trim();
      if (trimmed.isEmpty ||
          trimmed == '[draft]' ||
          trimmed.startsWith('[draft] ')) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.invalidEvidence,
          'transcript_unavailable',
        );
      }
      if (!source.remoteProcessingConsented) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.invalidEvidence,
          'remote_processing_consent_missing',
        );
      }
      if (citation.sourceRevision == null ||
          citation.sourceRevision != source.transcriptRevision) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.stale,
          'source_revision_mismatch',
        );
      }
      if (citation.quote.isEmpty) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.invalidEvidence,
          'empty_quote',
        );
      }

      final resolved = _resolveSpan(transcript, citation);
      if (resolved == null) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.invalidEvidence,
          'quote_span_invalid_or_ambiguous',
        );
      }
      final key =
          '${source.entryId}:${resolved.$1}:${resolved.$2}:${citation.role.name}';
      if (!seen.add(key)) continue;

      final sourceDate = source.createdAt.toUtc();
      if (sourceDate.year < 1970 ||
          sourceDate.isAfter(now.toUtc().add(const Duration(days: 1)))) {
        return EvidenceVerificationResult.invalid(
          ProofAdmissionOutcome.invalidEvidence,
          'source_date_invalid',
        );
      }
      verified.add(
        VerifiedEvidenceSnapshot(
          sourceEntryId: source.entryId,
          archiveScope: source.archiveScope,
          ownerScope: source.ownerScope,
          transcriptRevision: source.transcriptRevision,
          transcriptFingerprint: transcriptFingerprint(transcript),
          sourceDate: sourceDate,
          sourceType: source.sourceType,
          quote: citation.quote,
          startUtf16: resolved.$1,
          endUtf16: resolved.$2,
          role: citation.role,
          verifiedAt: now.toUtc(),
          verifierSchemaVersion: verifierSchemaVersion,
        ),
      );
    }

    if (verified.isEmpty) {
      return EvidenceVerificationResult.invalid(
        ProofAdmissionOutcome.insufficientEvidence,
        'no_verified_evidence',
      );
    }
    return EvidenceVerificationResult.valid(List.unmodifiable(verified));
  }

  (int, int)? _resolveSpan(String transcript, EvidenceCitationDraft citation) {
    final start = citation.startUtf16;
    final end = citation.endUtf16;
    if (start == null || end == null) {
      final matches = RegExp(
        RegExp.escape(citation.quote),
      ).allMatches(transcript).toList();
      if (matches.length != 1) return null;
      return (matches.single.start, matches.single.end);
    }
    if (start < 0 || end <= start || end > transcript.length) return null;
    if (!_isCodePointBoundary(transcript, start) ||
        !_isCodePointBoundary(transcript, end)) {
      return null;
    }
    if (transcript.substring(start, end) != citation.quote) return null;
    return (start, end);
  }

  bool _isCodePointBoundary(String value, int offset) {
    if (offset <= 0 || offset >= value.length) return true;
    final before = value.codeUnitAt(offset - 1);
    final after = value.codeUnitAt(offset);
    final splitsSurrogatePair =
        before >= 0xD800 &&
        before <= 0xDBFF &&
        after >= 0xDC00 &&
        after <= 0xDFFF;
    return !splitsSurrogatePair;
  }
}