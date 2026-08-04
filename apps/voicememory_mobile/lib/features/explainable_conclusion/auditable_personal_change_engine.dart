import '../../models/journal_entry.dart';
import '../insight_feedback/insight_feedback_models.dart';
import 'auditable_conclusion_trust_policy.dart';
import 'change_dimensions.dart';
import 'conclusion_confidence_model.dart';
import 'explainable_conclusion.dart';
import 'explainable_conclusion_validator.dart';

/// Deterministic comparison builder for the V1 semantic trust path.
///
/// It never calls a model. Two saved moments produce a conclusion only when
/// they share a subject and at least one comparison dimension that both
/// moments speak to actually moved. Confidence is derived from the evidence,
/// never assigned.
abstract final class AuditablePersonalChangeEngine {
  AuditablePersonalChangeEngine._();

  /// Builds the strongest defensible comparison between the newest usable
  /// moment and any eligible earlier moment.
  ///
  /// Search is not limited to archive positions one and two: a later moment
  /// can still form the first genuine comparison with an older one.
  static RankedAuditableConclusion? buildEarlyComparison({
    required List<JournalEntry> entries,
    Iterable<InsightFeedbackRecord> feedback = const [],
    Set<String> userConfirmedThreadIds = const {},
  }) {
    final usable = _usable(entries);
    if (usable.length < 2) return null;

    final now = usable.last;
    final transcripts = {
      for (final entry in usable) entry.id: entry.transcript,
    };
    for (final then in usable.reversed.skip(1)) {
      final pair = _alignedPair(then, now);
      if (pair == null) continue;
      final conclusion = _conclusionFor(then: then, now: now, pair: pair);
      if (conclusion == null) continue;
      final ranked = AuditableConclusionTrustPolicy.rankBest(
        candidates: [conclusion],
        canonicalTranscripts: transcripts,
        feedback: feedback,
        entryThreadIds: {
          for (final entry in usable) entry.id: entry.archiveThreadId,
        },
        userConfirmedThreadIds: userConfirmedThreadIds,
        // Defence in depth. Placeholders are already excluded from [usable],
        // but a citation naming one by id must still be refused rather than
        // silently accepted because the set was left empty.
        generatedTextEntryIds: {
          for (final entry in entries)
            if (holdsGeneratedPlaceholder(entry)) entry.id,
        },
      );
      if (ranked != null) return ranked;
    }
    return null;
  }

  /// Every earlier moment that could form a defensible comparison with
  /// [candidate], newest first. Used to count genuine comparison material
  /// without exposing the moments themselves.
  static List<JournalEntry> eligibleRelatedMoments({
    required List<JournalEntry> entries,
    required JournalEntry candidate,
  }) {
    final usable = _usable(entries);
    return usable.reversed
        .where(
          (entry) =>
              entry.id != candidate.id &&
              _alignedPair(entry, candidate) != null,
        )
        .toList(growable: false);
  }

  static bool areRelated(JournalEntry then, JournalEntry now) =>
      _alignedPair(then, now, requireMovedDimension: false) != null;

  /// True when the transcript is an app-authored placeholder rather than the
  /// user's words — an audio-only save, or a recovered recording awaiting
  /// transcription.
  ///
  /// Such text is long enough to clear the length filter and reads like a
  /// sentence, so without this it can be quoted back to the user as evidence
  /// of something they said. Nothing here may cite words the user never spoke.
  static bool holdsGeneratedPlaceholder(JournalEntry entry) =>
      entry.transcript.trimLeft().startsWith('[draft]');

  static List<JournalEntry> _usable(List<JournalEntry> entries) =>
      entries
          .where(
            (entry) =>
                !entry.isArchived &&
                !entry.isDeleted &&
                entry.id.trim().isNotEmpty &&
                !holdsGeneratedPlaceholder(entry) &&
                entry.transcript.trim().length >= 12,
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  static _AlignedPair? _alignedPair(
    JournalEntry then,
    JournalEntry now, {
    bool requireMovedDimension = true,
  }) {
    if (then.id == now.id || !then.createdAt.isBefore(now.createdAt)) {
      return null;
    }
    final thenQuote = _quote(then.transcript);
    final nowQuote = _quote(now.transcript);
    if (_normalized(thenQuote) == _normalized(nowQuote)) return null;

    final dimensions = ChangeDimensionReader.compare(
      before: thenQuote,
      after: nowQuote,
    );
    final explicitThread =
        then.archiveThreadId?.isNotEmpty == true &&
            then.archiveThreadId == now.archiveThreadId ||
        then.captureContextTag?.isNotEmpty == true &&
            then.captureContextTag == now.captureContextTag;
    if (dimensions.sharedSubjectMarkers.isEmpty && !explicitThread) return null;
    if (!dimensions.hasComparableDimension) return null;
    if (dimensions.isConflicting) return null;
    if (requireMovedDimension && !dimensions.supportsChange) return null;

    final subject = _subjectOf(dimensions, then, now);
    if (subject == null) return null;
    return _AlignedPair(
      thenQuote: thenQuote,
      nowQuote: nowQuote,
      subject: subject,
      dimensions: dimensions,
      threadAligned:
          explicitThread || dimensions.sharedSubjectMarkers.isNotEmpty,
    );
  }

  /// The most specific shared word, not the alphabetically first one.
  ///
  /// Specificity is length-ranked because a longer shared content word is a
  /// narrower claim about what the two moments have in common. Ties resolve
  /// alphabetically only so the result stays deterministic.
  static String? _subjectOf(
    ChangeDimensions dimensions,
    JournalEntry then,
    JournalEntry now,
  ) {
    final shared = dimensions.sharedSubjectMarkers.toList()
      ..sort((a, b) {
        final byLength = b.length.compareTo(a.length);
        return byLength != 0 ? byLength : a.compareTo(b);
      });
    final best = shared.firstOrNull;
    if (best != null) return best;
    final tag = then.captureContextTag?.trim().replaceAll('_', ' ');
    if (tag?.isNotEmpty == true) return tag;
    return now.captureContextTag?.trim().replaceAll('_', ' ');
  }

  static ExplainableConclusion? _conclusionFor({
    required JournalEntry then,
    required JournalEntry now,
    required _AlignedPair pair,
  }) {
    final movement = _leadMovement(pair.dimensions);
    if (movement == null) return null;
    final generatedAt = DateTime.now().toUtc();
    final thenCitation = _citation(
      then,
      pair.thenQuote,
      EvidenceTemporalRole.then,
    );
    final nowCitation = _citation(now, pair.nowQuote, EvidenceTemporalRole.now);
    final evidence = [thenCitation, nowCitation];

    final signals = ConclusionConfidenceModel.forComparison(
      dimensions: pair.dimensions,
      quotes: [pair.thenQuote, pair.nowQuote],
      distinctSourceCount: 2,
      citationsValid: true,
      chronologyOrdered: true,
      threadAligned: pair.threadAligned,
    );
    final derived = signals.value;
    if (derived <= 0) return null;
    // Derived confidence can never exceed what the evidence structurally
    // supports, so the two gates cannot disagree.
    final confidence = derived.clamp(
      0,
      ExplainableConclusionValidator.evidenceConfidenceCap(evidence),
    );
    if (confidence <= 0) return null;

    return ExplainableConclusion(
      id: 'early_change_${then.id}_${now.id}',
      statement:
          '${_capitalize(pair.subject)} — ${movement.dimension.label} looks '
          'different across these two saved moments.',
      confidence: confidence,
      reasoning: [
        'Both saved moments mention ${pair.subject}.',
        'The earlier moment says '
            '"${_markerList(movement.before.markers)}" and the newer moment '
            'says "${_markerList(movement.after.markers)}".',
      ],
      uncertaintyNote: signals.uncertaintyNote,
      evidence: evidence,
      alternatives: const [
        ExplainableAlternative(
          statement:
              'The difference may reflect the circumstances of these two '
              'moments rather than an ongoing change.',
          rationale:
              'ArchiveMe has two related saved moments, so later evidence '
              'could support or challenge this comparison.',
        ),
      ],
      provenance: ExplainableConclusionProvenance(
        source: 'auditable_personal_change',
        generatedAt: generatedAt,
        schemaVersion: ExplainableConclusion.schemaVersion,
        sourceRevision: 'early_change_v2',
      ),
      kind: ExplainableInsightKind.change,
      nextRecordingPrompt:
          'If ${pair.subject} comes up again, what did you do or feel '
          'differently this time?',
      theoryId: 'early_change_v2',
    );
  }

  /// Prefer the dimension whose movement is most concrete to a reader.
  static DimensionMovement? _leadMovement(ChangeDimensions dimensions) {
    final changed = dimensions.changed;
    if (changed.isEmpty) return null;
    final ordered = List<DimensionMovement>.from(changed)
      ..sort(
        (a, b) => _dimensionPriority(
          a.dimension,
        ).compareTo(_dimensionPriority(b.dimension)),
      );
    return ordered.first;
  }

  static int _dimensionPriority(ChangeDimension dimension) =>
      switch (dimension) {
        ChangeDimension.action => 0,
        ChangeDimension.behaviouralResponse => 1,
        ChangeDimension.stoppingOrCompletionBehaviour => 2,
        ChangeDimension.copingResponse => 3,
        ChangeDimension.outcome => 4,
        ChangeDimension.emotionalState => 5,
        ChangeDimension.emotionalIntensity => 6,
        ChangeDimension.certainty => 7,
        ChangeDimension.frequency => 8,
        ChangeDimension.duration => 9,
        ChangeDimension.situation => 10,
      };

  static TranscriptEvidenceCitation _citation(
    JournalEntry entry,
    String quote,
    EvidenceTemporalRole temporalRole,
  ) {
    final start = entry.transcript.indexOf(quote);
    return TranscriptEvidenceCitation(
      entryId: entry.id,
      quote: quote,
      startUtf16: start,
      endUtf16: start + quote.length,
      role: TranscriptEvidenceRole.supporting,
      // No transcript-to-audio alignment exists on device, so there is no
      // honest offset to jump to. A null timestamp hides the audio action
      // instead of sending the user to the start of the recording.
      audioTimestampMs: null,
      audioVaultReference: entry.localAudioVaultRef,
      sourceCapturedAt: entry.createdAt,
      sourceType: entry.localAudioReference == null
          ? EvidenceSourceType.text
          : EvidenceSourceType.voice,
      temporalRole: temporalRole,
      confidenceScore: _citationConfidence(quote),
    );
  }

  /// How much of the quote is concrete language rather than filler.
  static double _citationConfidence(String quote) =>
      (0.6 + ConclusionConfidenceModel.specificityOf([quote]) * 0.4).clamp(
        0.0,
        1.0,
      );

  static String _markerList(Set<String> markers) {
    final ordered = markers.toList()..sort();
    return ordered.join(', ');
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  static String _quote(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.length <= 220) return trimmed;
    final sentenceEnd = trimmed.indexOf(RegExp(r'[.!?](?:\s|$)'));
    if (sentenceEnd >= 11 && sentenceEnd < 220) {
      return trimmed.substring(0, sentenceEnd + 1);
    }
    return trimmed.substring(0, 220).trimRight();
  }

  static String _normalized(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _AlignedPair {
  const _AlignedPair({
    required this.thenQuote,
    required this.nowQuote,
    required this.subject,
    required this.dimensions,
    required this.threadAligned,
  });

  final String thenQuote;
  final String nowQuote;
  final String subject;
  final ChangeDimensions dimensions;
  final bool threadAligned;
}
