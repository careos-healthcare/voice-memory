import 'package:archiveme_mobile/features/belief_evidence/evidence/transcript_evidence_index.dart';
import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';

/// Why a claim cannot be shown with words taken from the archive.
enum EvidenceGroundingFailure {
  /// The referenced entry's stored text was not available to check against.
  sourceUnavailable,

  /// Stored text was available and the candidate does not appear in it.
  ///
  /// This is the case that matters: the candidate was paraphrased, stitched
  /// together from more than one entry, or otherwise generated.
  notPresentInSource,

  /// Too short to stand on its own as a quote.
  tooShortToQuote,
}

/// A run of characters proven to exist, character for character, inside a
/// stored transcript.
///
/// [text] is sliced out of the source transcript itself rather than copied
/// from the caller's candidate string, and the private constructor means
/// [VerbatimEvidenceVerifier] is the only way to obtain one. A caller cannot
/// hand a generated string to the citation widgets and have it rendered as a
/// quote.
class VerbatimEvidence {
  const VerbatimEvidence._({
    required this.entryId,
    required this.text,
    required this.sourceStart,
    required this.sourceEnd,
    required this.sourceLength,
    required this.recordedAt,
    required this.label,
  });

  final String entryId;

  /// Exactly `sourceTranscript.substring(sourceStart, sourceEnd)`.
  final String text;

  final int sourceStart;
  final int sourceEnd;

  /// Length of the full stored transcript this was taken from.
  final int sourceLength;

  final DateTime? recordedAt;
  final String? label;

  /// Whether the quote is the whole stored transcript rather than an excerpt.
  bool get isWholeSource => sourceStart == 0 && sourceEnd >= sourceLength;

  /// Whether stored words come before or after the quoted run.
  bool get isExcerpt => !isWholeSource;
}

/// Result of checking one candidate quote against stored text.
class EvidenceGrounding {
  const EvidenceGrounding._(this.evidence, this.failure);

  const EvidenceGrounding.grounded(VerbatimEvidence evidence)
    : this._(evidence, null);

  const EvidenceGrounding.ungrounded(EvidenceGroundingFailure failure)
    : this._(null, failure);

  final VerbatimEvidence? evidence;
  final EvidenceGroundingFailure? failure;

  bool get isGrounded => evidence != null;
}

/// Checks candidate quotes against the transcript actually held in storage.
///
/// Matching is whitespace-insensitive and case-insensitive so that a candidate
/// carrying different spacing or sentence casing still resolves, but the text
/// handed back is always the stored spelling, spacing, and punctuation.
abstract final class VerbatimEvidenceVerifier {
  VerbatimEvidenceVerifier._();

  /// Below this a quote is a fragment rather than something a user can
  /// recognise as their own words.
  static const int minimumQuoteLength = 8;

  /// Trailing markers that upstream indexing appends when it shortens a line.
  static final RegExp _truncationMarker = RegExp(r'(\u2026|\.{3})\s*$');

  static EvidenceGrounding verify({
    required String entryId,
    required String candidate,
    required String? sourceText,
    DateTime? recordedAt,
    String? label,
  }) {
    final wanted = _fold(candidate.replaceFirst(_truncationMarker, ''));
    if (wanted.length < minimumQuoteLength) {
      return const EvidenceGrounding.ungrounded(
        EvidenceGroundingFailure.tooShortToQuote,
      );
    }

    final source = sourceText ?? '';
    if (source.trim().isEmpty) {
      return const EvidenceGrounding.ungrounded(
        EvidenceGroundingFailure.sourceUnavailable,
      );
    }

    final folded = _FoldedSource(source);
    final at = folded.text.indexOf(wanted);
    if (at < 0) {
      return const EvidenceGrounding.ungrounded(
        EvidenceGroundingFailure.notPresentInSource,
      );
    }

    var start = folded.originalIndexAt(at);
    var end = folded.originalIndexAt(at + wanted.length - 1) + 1;

    // A candidate can land mid-word (for example when upstream shortened it
    // to a character budget). Growing the span to the enclosing word keeps the
    // quote readable and still takes every character from storage.
    while (start > 0 && _isWordChar(source.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < source.length && _isWordChar(source.codeUnitAt(end))) {
      end++;
    }

    return EvidenceGrounding.grounded(
      VerbatimEvidence._(
        entryId: entryId,
        text: source.substring(start, end),
        sourceStart: start,
        sourceEnd: end,
        sourceLength: source.length,
        recordedAt: recordedAt,
        label: label,
      ),
    );
  }

  /// Verifies against the transcript held for [line]'s entry.
  static EvidenceGrounding groundLine(
    InsightEvidenceLine line, {
    String? sourceText,
  }) {
    return verify(
      entryId: line.entryId,
      candidate: line.quote,
      sourceText: sourceText ?? TranscriptEvidenceIndex.transcriptFor(line.entryId),
      recordedAt: line.recordedAt,
      label: line.label,
    );
  }

  /// Verified quotes only — ungrounded lines are dropped, never substituted.
  static List<VerbatimEvidence> groundLines(
    Iterable<InsightEvidenceLine> lines,
  ) {
    final out = <VerbatimEvidence>[];
    final seen = <String>{};
    for (final line in lines) {
      final grounding = groundLine(line);
      final evidence = grounding.evidence;
      if (evidence == null) continue;
      if (!seen.add('${evidence.entryId}:${evidence.sourceStart}')) continue;
      out.add(evidence);
    }
    return out;
  }

  /// The failure that best explains why [lines] produced no quote.
  ///
  /// [EvidenceGroundingFailure.notPresentInSource] wins over the others: if
  /// any line was checkable and failed, the honest message is that the words
  /// are not in the archive, not that the archive was unreachable.
  static EvidenceGroundingFailure summariseFailure(
    Iterable<InsightEvidenceLine> lines,
  ) {
    var sawUnavailable = false;
    var sawTooShort = false;
    for (final line in lines) {
      switch (groundLine(line).failure) {
        case EvidenceGroundingFailure.notPresentInSource:
          return EvidenceGroundingFailure.notPresentInSource;
        case EvidenceGroundingFailure.sourceUnavailable:
          sawUnavailable = true;
        case EvidenceGroundingFailure.tooShortToQuote:
          sawTooShort = true;
        case null:
          break;
      }
    }
    if (sawUnavailable) return EvidenceGroundingFailure.sourceUnavailable;
    if (sawTooShort) return EvidenceGroundingFailure.tooShortToQuote;
    return EvidenceGroundingFailure.sourceUnavailable;
  }

  static bool _isWordChar(int codeUnit) {
    final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
    final isUpper = codeUnit >= 0x41 && codeUnit <= 0x5A;
    final isLower = codeUnit >= 0x61 && codeUnit <= 0x7A;
    return isDigit || isUpper || isLower || codeUnit > 0x7F;
  }

  /// Lowercases and collapses whitespace without changing character count,
  /// so folded offsets stay usable against the original string.
  static String _fold(String value) => _FoldedSource(value).text.trim();
}

/// A whitespace-collapsed, lowercased view of a source string that can map any
/// of its offsets back to the original.
class _FoldedSource {
  factory _FoldedSource(String source) {
    final buffer = StringBuffer();
    final offsets = <int>[];
    var pendingSpace = false;
    var wroteAny = false;

    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (_isWhitespace(char)) {
        if (wroteAny) pendingSpace = true;
        continue;
      }
      if (pendingSpace) {
        buffer.write(' ');
        offsets.add(i);
        pendingSpace = false;
      }
      final lower = char.toLowerCase();
      buffer.write(lower.length == 1 ? lower : char);
      offsets.add(i);
      wroteAny = true;
    }

    return _FoldedSource._(buffer.toString(), offsets);
  }

  const _FoldedSource._(this.text, this._offsets);

  final String text;
  final List<int> _offsets;

  int originalIndexAt(int foldedIndex) => _offsets[foldedIndex];

  static bool _isWhitespace(String char) {
    switch (char) {
      case ' ':
      case '\t':
      case '\n':
      case '\r':
      case '\u000B':
      case '\u000C':
      case '\u00A0':
        return true;
      default:
        return false;
    }
  }
}
