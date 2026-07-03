import '../archive_evidence/comparable_evidence_text.dart';
import '../../models/journal_entry.dart';
import '../acquisition/audience_wedge_model.dart';
import '../loop_mode/loop_mode_engine.dart';
import '../loop_mode/loop_mode_model.dart';
import '../first_session/first_session_pattern_model.dart';
import '../interpretation/interpretation_quality_engine.dart';
import '../interpretation/interpretation_read_model.dart';
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
    return _legacyBuild(
      pattern,
      reflectionCount: reflectionCount,
      categoryRepeated: categoryRepeated,
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
    final result = _interpretationEngine.build(
      latestEntry: entry,
      priorEntries: priorEntries,
      feedback: feedback,
      selectedSignal: selectedSignal,
      patternHint: pattern,
      audienceWedge: audienceWedge,
      activeLoop: activeLoop,
    );

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
        );
      }).toList();
    }

    if (signals.length < 2 && !result.needsClearerMoment) {
      final legacy = _legacyBuild(
        pattern,
        reflectionCount: reflectionCount,
        categoryRepeated: categoryRepeated || result.archiveRepeatDetected,
      );
      for (final alt in legacy.signals) {
        if (signals.length >= 3) break;
        if (signals.any(
          (s) => s.readId == alt.readId || s.title == alt.title,
        )) {
          continue;
        }
        signals.add(alt);
      }
    }

    return PostSaveInsightBundle(
      signals: signals.take(3).toList(),
      sourcePattern: pattern,
      needsClearerMoment: result.needsClearerMoment,
      clearerMomentPrompt: result.clearerMomentPrompt,
      archiveRepeatDetected: result.archiveRepeatDetected,
      changedAngleDetected: result.changedAngleDetected,
    );
  }

  /// Next alternative when user taps Not me / Show another angle.
  PostSaveInsightSignal? alternativeFor({
    required PostSaveInsightBundle bundle,
    required PostSaveInsightSignal current,
    required int rotation,
    JournalEntry? entry,
  }) {
    if (entry != null && current.readId != null) {
      final text = ComparableEvidenceText.userText(entry);
      if (text.trim().isEmpty) return null;
      final normalized = text.toLowerCase();
      final alts = _interpretationEngine.alternativesFor(
        primaryReadId: current.readId!,
        normalizedText: normalized,
        fragments: current.evidenceChips,
        tags: current.evidenceChips,
      );
      if (alts.isNotEmpty) {
        return _signalFromRead(
          alts[rotation % alts.length],
          bundle.sourcePattern,
        );
      }
    }

    final pool = bundle.signals
        .where((s) => s.categoryId != current.categoryId)
        .toList();
    if (pool.isEmpty) return null;
    return pool[rotation % pool.length];
  }

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

  PostSaveInsightBundle _legacyBuild(
    FirstSessionPattern pattern, {
    int reflectionCount = 1,
    bool categoryRepeated = false,
  }) {
    final signals = <PostSaveInsightSignal>[
      _legacyPrimary(pattern, categoryRepeated: categoryRepeated),
    ];
    for (final alt in pattern.alternativePatterns.take(2)) {
      if (signals.length >= 3) break;
      if (signals.any((s) => s.categoryId == alt.categoryId)) continue;
      signals.add(_legacyAlternative(alt, pattern));
    }
    while (signals.length < 2) {
      break;
    }
    return PostSaveInsightBundle(
      signals: signals.take(3).toList(),
      sourcePattern: pattern,
    );
  }

  PostSaveInsightSignal _legacyPrimary(
    FirstSessionPattern pattern, {
    bool categoryRepeated = false,
  }) {
    return PostSaveInsightSignal(
      id: '${pattern.id}_primary',
      title: pattern.title,
      explanation: pattern.matchReason.trim().isNotEmpty
          ? pattern.matchReason
          : pattern.whyNoticed,
      mightMean: 'This may be one possible read on what you recorded.',
      wouldConfirm: 'The same situation or feeling keeps showing up.',
      wouldContradict: 'This moment feels one-off and does not repeat.',
      recordNextQuestion:
          'What part of today might be worth recording again tomorrow?',
      categoryId: pattern.categoryId,
      evidenceLine: pattern.sourceTextPreview.trim().isNotEmpty
          ? pattern.sourceTextPreview
          : null,
      strengthLabel: categoryRepeated ? 'Possible repeat' : 'Early signal',
      whySuggested: pattern.whyNoticed,
      evidenceChips: pattern.chips,
      isPrimary: true,
    );
  }

  PostSaveInsightSignal _legacyAlternative(
    FirstSessionPatternAlternative alt,
    FirstSessionPattern pattern,
  ) {
    return PostSaveInsightSignal(
      id: 'alt_${alt.categoryId}',
      title: alt.title,
      explanation: alt.whyNoticed,
      mightMean: 'This may be another way to read the same moment.',
      wouldConfirm: 'This angle keeps showing up in similar moments.',
      wouldContradict: 'This angle does not fit your next moments.',
      recordNextQuestion: 'What would confirm or contradict this read?',
      categoryId: alt.categoryId,
      strengthLabel: 'Early signal',
      whySuggested: alt.whyNoticed,
      evidenceChips: alt.chips,
    );
  }
}
