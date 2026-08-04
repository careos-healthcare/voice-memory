import '../../models/journal_entry.dart';
import '../acquisition/audience_wedge_model.dart';
import '../loop_mode/loop_mode_engine.dart';
import '../loop_mode/loop_mode_model.dart';
import '../first_session/first_session_pattern_model.dart';
import '../explainable_conclusion/auditable_conclusion_trust_policy.dart';
import '../explainable_conclusion/auditable_personal_change_engine.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../insight_feedback/insight_feedback_store.dart';
import '../interpretation/interpretation_quality_engine.dart';
import '../interpretation/interpretation_read_model.dart';
import '../impossible_insight/impossible_insight_mappers.dart';
import 'post_save_insight_models.dart';
import 'selected_signal_model.dart';
import 'signal_feedback_model.dart';

/// Builds post-save insight signals from evidence-grounded interpretation reads.
class PostSaveInsightEngine {
  const PostSaveInsightEngine();

  static const _interpretationEngine = InterpretationQualityEngine();

  PostSaveInsightBundle build(
    FirstSessionPattern pattern, {
    JournalEntry? entry,
    List<JournalEntry> priorEntries = const [],
    List<PostSaveSignalFeedback> feedback = const [],
    SelectedSignalRecord? selectedSignal,
    AudienceWedge? audienceWedge,
    LoopMode? activeLoop,
    int reflectionCount = 1,
    bool categoryRepeated = false,
  }) {
    if (entry != null) {
      return _buildFromInterpretation(
        pattern: pattern,
        entry: entry,
        priorEntries: priorEntries,
        feedback: feedback,
        selectedSignal: selectedSignal,
        audienceWedge: audienceWedge,
        activeLoop: activeLoop,
        reflectionCount: reflectionCount,
        categoryRepeated: categoryRepeated,
      );
    }
    return PostSaveInsightBundle(
      signals: const [],
      sourcePattern: pattern,
      needsClearerMoment: true,
      clearerMomentPrompt: 'Record a clearer moment before showing a read.',
    );
  }

  PostSaveInsightBundle _buildFromInterpretation({
    required FirstSessionPattern pattern,
    required JournalEntry entry,
    List<JournalEntry> priorEntries = const [],
    List<PostSaveSignalFeedback> feedback = const [],
    SelectedSignalRecord? selectedSignal,
    AudienceWedge? audienceWedge,
    LoopMode? activeLoop,
    int reflectionCount = 1,
    bool categoryRepeated = false,
  }) {
    final earlyComparison = AuditablePersonalChangeEngine.buildEarlyComparison(
      entries: [...priorEntries, entry],
      feedback: InsightFeedbackStore.cached,
    );
    if (earlyComparison != null) {
      return PostSaveInsightBundle(
        signals: [
          _signalFromConclusion(earlyComparison.conclusion.value, pattern),
        ],
        sourcePattern: pattern,
        changedAngleDetected: true,
      );
    }

    final result = _interpretationEngine.build(
      latestEntry: entry,
      priorEntries: priorEntries,
      feedback: feedback,
      selectedSignal: selectedSignal,
      patternHint: pattern,
      audienceWedge: audienceWedge,
      activeLoop: activeLoop,
    );

    if (result.impossibleInsight case final impossible?) {
      return PostSaveInsightBundle(
        signals: [ImpossibleInsightMappers.toPostSaveSignal(impossible)],
        sourcePattern: pattern,
        archiveRepeatDetected: result.archiveRepeatDetected,
        impossibleInsight: impossible,
      );
    }

    if (result.needsClearerMoment && result.reads.isEmpty) {
      return PostSaveInsightBundle(
        signals: const [],
        sourcePattern: pattern,
        needsClearerMoment: true,
        clearerMomentPrompt: result.clearerMomentPrompt,
        clearerMomentTitle: result.clearerMomentTitle,
        loopUnsupported: result.loopUnsupported,
      );
    }

    var signals = result.reads
        .map(
          (read) => _signalFromRead(
            read,
            pattern,
            isPrimary: read == result.reads.first,
          ),
        )
        .toList();

    if (activeLoop != null &&
        activeLoop.isFullyImplementedLoop &&
        signals.isNotEmpty) {
      const loopEngine = LoopModeEngine();
      signals = signals.map((s) {
        if (!s.isPrimary) return s;
        return PostSaveInsightSignal(
          id: s.id,
          readId: s.readId,
          title: s.title,
          explanation: s.explanation,
          mightMean: s.mightMean,
          wouldConfirm: loopEngine.wouldConfirmFor(activeLoop),
          wouldContradict: loopEngine.wouldChallengeFor(activeLoop),
          recordNextQuestion: s.recordNextQuestion,
          categoryId: s.categoryId,
          evidenceLine: s.evidenceLine,
          angleCategory: s.angleCategory,
          strengthLabel: s.strengthLabel,
          whySuggested: s.whySuggested,
          evidenceChips: s.evidenceChips,
          isPrimary: true,
          evidenceUsed: s.evidenceUsed,
          explainableConclusion: s.explainableConclusion,
        );
      }).toList();
    }

    signals = _strictSignals(
      signals,
      entry,
      priorEntries: priorEntries,
    ).take(1).toList(growable: false);
    return PostSaveInsightBundle(
      signals: signals,
      sourcePattern: pattern,
      needsClearerMoment: signals.isEmpty,
      clearerMomentPrompt: signals.isEmpty
          ? 'What felt most specific about this moment, and what happened next?'
          : result.clearerMomentPrompt,
      clearerMomentTitle: signals.isEmpty
          ? 'Saved. ArchiveMe does not have enough evidence for a reliable '
                'observation yet.'
          : result.clearerMomentTitle,
      archiveRepeatDetected: result.archiveRepeatDetected,
      changedAngleDetected: result.changedAngleDetected,
    );
  }

  List<PostSaveInsightSignal> _strictSignals(
    List<PostSaveInsightSignal> signals,
    JournalEntry entry, {
    required List<JournalEntry> priorEntries,
  }) {
    final transcripts = {
      for (final item in [...priorEntries, entry]) item.id: item.transcript,
    };
    final candidates =
        <({PostSaveInsightSignal signal, ExplainableConclusion conclusion})>[];
    for (final signal in signals) {
      String? quote;
      int? quoteStart;
      for (final candidate in [
        signal.evidenceUsed,
        signal.evidenceLine,
        ...signal.evidenceChips,
      ]) {
        final value = candidate?.trim() ?? '';
        final start = value.isEmpty ? -1 : entry.transcript.indexOf(value);
        if (start >= 0) {
          quote = value;
          quoteStart = start;
          break;
        }
      }
      if (quote == null || quoteStart == null) continue;
      final conclusion = ExplainableConclusion(
        id: 'post_save_${entry.id}_${signal.id}',
        statement: signal.title,
        confidence: 70,
        reasoning: [
          signal.evidenceLine ?? signal.evidenceUsed ?? quote,
          signal.explanation,
        ],
        uncertaintyNote: signal.wouldContradict,
        evidence: [
          TranscriptEvidenceCitation(
            entryId: entry.id,
            quote: quote,
            startUtf16: quoteStart,
            endUtf16: quoteStart + quote.length,
            role: TranscriptEvidenceRole.supporting,
            sourceCapturedAt: entry.createdAt,
            sourceType: entry.localAudioReference == null
                ? EvidenceSourceType.text
                : EvidenceSourceType.voice,
          ),
        ],
        alternatives: [
          ExplainableAlternative(
            statement:
                'This may be specific to this moment rather than something '
                'that repeats.',
            rationale:
                'ArchiveMe has only one supporting moment for this '
                'observation so far.',
          ),
        ],
        provenance: ExplainableConclusionProvenance(
          source: 'post_save_interpretation',
          generatedAt: DateTime.now().toUtc(),
          schemaVersion: ExplainableConclusion.schemaVersion,
          sourceRevision: 'auditable_observation_v1',
        ),
        kind: ExplainableInsightKind.observation,
        nextRecordingPrompt: signal.recordNextQuestion,
        theoryId: signal.readId ?? signal.categoryId,
      );
      candidates.add((signal: signal, conclusion: conclusion));
    }
    final ranked = AuditableConclusionTrustPolicy.rankBest(
      candidates: candidates.map((item) => item.conclusion),
      canonicalTranscripts: transcripts,
      feedback: InsightFeedbackStore.cached,
    );
    if (ranked == null) return const [];
    final source = candidates
        .where((item) => item.conclusion.id == ranked.conclusion.value.id)
        .firstOrNull;
    if (source == null) return const [];
    return [_withConclusion(source.signal, ranked.conclusion.value)];
  }

  PostSaveInsightSignal _withConclusion(
    PostSaveInsightSignal signal,
    ExplainableConclusion conclusion,
  ) => PostSaveInsightSignal(
    id: signal.id,
    title: signal.title,
    explanation: signal.explanation,
    mightMean: signal.mightMean,
    wouldConfirm: signal.wouldConfirm,
    wouldContradict: signal.wouldContradict,
    recordNextQuestion: signal.recordNextQuestion,
    categoryId: signal.categoryId,
    evidenceLine: signal.evidenceLine,
    angleCategory: signal.angleCategory,
    strengthLabel: signal.strengthLabel,
    whySuggested: signal.whySuggested,
    evidenceChips: signal.evidenceChips,
    isPrimary: signal.isPrimary,
    evidenceUsed: signal.evidenceUsed,
    readId: signal.readId,
    explainableConclusion: conclusion,
  );

  /// Next alternative when user taps Not me / Show another angle.
  PostSaveInsightSignal? alternativeFor({
    required PostSaveInsightBundle bundle,
    required PostSaveInsightSignal current,
    required int rotation,
    JournalEntry? entry,
  }) => null;

  PostSaveInsightSignal _signalFromConclusion(
    ExplainableConclusion conclusion,
    FirstSessionPattern pattern,
  ) => PostSaveInsightSignal(
    id: conclusion.id,
    readId: conclusion.theoryId,
    title: conclusion.statement,
    explanation: conclusion.reasoning.first,
    mightMean: conclusion.statement,
    wouldConfirm: conclusion.reasoning.last,
    wouldContradict: conclusion.uncertaintyNote,
    recordNextQuestion: conclusion.nextRecordingPrompt ?? '',
    categoryId: conclusion.theoryId ?? pattern.categoryId,
    evidenceLine: conclusion.evidence.firstOrNull?.quote,
    strengthLabel: 'Possible change',
    whySuggested: conclusion.reasoning.first,
    evidenceChips: conclusion.evidence
        .map((citation) => citation.quote)
        .toList(growable: false),
    evidenceUsed: conclusion.evidence.firstOrNull?.quote,
    isPrimary: true,
    explainableConclusion: conclusion,
  );

  PostSaveInsightSignal _signalFromRead(
    InterpretationRead read,
    FirstSessionPattern pattern, {
    bool isPrimary = false,
  }) {
    return PostSaveInsightSignal(
      id: '${read.id}_${pattern.id}',
      readId: read.id,
      title: read.title,
      explanation: read.shortRead,
      mightMean: read.mightMean,
      wouldConfirm: read.whatWouldConfirm,
      wouldContradict: read.whatWouldContradict,
      recordNextQuestion: read.nextEvidencePrompt,
      categoryId: read.categoryId,
      evidenceLine: read.evidenceFragments.isNotEmpty
          ? read.evidenceFragments.first
          : null,
      angleCategory: read.angleCategory,
      strengthLabel: read.strengthLabel,
      whySuggested: read.whyThisRead,
      evidenceChips: read.evidenceTags.isNotEmpty
          ? read.evidenceTags
          : read.evidenceFragments,
      evidenceUsed: read.evidenceUsed,
      isPrimary: isPrimary,
    );
  }
}
