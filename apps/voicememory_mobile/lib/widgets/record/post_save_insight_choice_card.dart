import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/acquisition/audience_wedge_model.dart';
import '../../features/loop_mode/loop_mode_coordinator.dart';
import '../../features/loop_mode/loop_mode_engine.dart';
import '../../features/loop_mode/loop_mode_model.dart';
import '../../product/loop_mode_copy.dart';
import '../../features/first_session/first_session_pattern_model.dart';
import '../../features/quality/first_insight_specificity_store.dart';
import '../../features/signal_archive/signal_archive_navigation.dart';
import '../../features/quality/interpretation_quality_signal_engine.dart';
import '../../features/quality/interpretation_quality_signal_model.dart';
import '../../features/quality/interpretation_quality_store.dart';
import '../../features/retention/next_evidence_reminder_service.dart';
import '../../features/retention/reminder_pre_prompt_coordinator.dart';
import '../../features/signal_journey/signal_journey_coordinator.dart';
import '../../widgets/record/first_insight_sharpness_row.dart';
import '../../widgets/retention/reminder_pre_prompt_sheet.dart';
import '../../models/journal_entry.dart';
import '../../features/post_save_insight/selected_signal_model.dart';
import '../../features/post_save_insight/next_evidence_prompt_engine.dart';
import '../../features/post_save_insight/post_save_insight_engine.dart';
import '../../features/post_save_insight/post_save_insight_models.dart';
import '../../features/post_save_insight/selected_signal_coordinator.dart';
import '../../features/post_save_insight/signal_feedback_coordinator.dart';
import '../../features/post_save_insight/signal_feedback_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'next_evidence_prompt_card.dart';
import 'post_save_clearer_moment_banner.dart';
import '../prove_enough/prove_enough_post_record_payoff.dart';

enum _PostSaveInsightPhase {
  abChoice,
  allSignals,
  deeper,
  alternative,
  savedWithPrompt,
}

/// Post-save insight choice with A/B reads, strength scoring, and next prompt.
class PostSaveInsightChoiceCard extends StatefulWidget {
  const PostSaveInsightChoiceCard({
    super.key,
    required this.pattern,
    required this.onSaveSignal,
    required this.onRecordNext,
    this.onViewPatterns,
    this.entryId,
    this.onRecordNextEvidence,
    this.onUsePrompt,
    this.reflectionCount = 1,
    this.audienceWedge,
    this.activeLoop,
    this.categoryRepeated = false,
    this.entry,
    this.priorEntries = const [],
    this.feedback = const [],
    this.selectedSignal,
  });

  final FirstSessionPattern pattern;
  final Future<void> Function(FirstSessionPattern pattern) onSaveSignal;
  final VoidCallback onRecordNext;
  final VoidCallback? onViewPatterns;
  final String? entryId;
  final void Function(String prompt)? onRecordNextEvidence;
  final Future<void> Function(String prompt)? onUsePrompt;
  final int reflectionCount;
  final AudienceWedge? audienceWedge;
  final LoopMode? activeLoop;
  final bool categoryRepeated;
  final JournalEntry? entry;
  final List<JournalEntry> priorEntries;
  final List<PostSaveSignalFeedback> feedback;
  final SelectedSignalRecord? selectedSignal;

  @override
  State<PostSaveInsightChoiceCard> createState() =>
      _PostSaveInsightChoiceCardState();
}

class _PostSaveInsightChoiceCardState extends State<PostSaveInsightChoiceCard> {
  static const _engine = PostSaveInsightEngine();
  static const _promptEngine = NextEvidencePromptEngine();
  static const _qualityEngine = InterpretationQualitySignalEngine();

  late PostSaveInsightBundle _bundle;
  late _PostSaveInsightPhase _phase;
  PostSaveInsightSignal? _selected;
  int _alternativeRotation = 0;
  int _promptRotation = 0;
  bool _busy = false;
  bool _promptSaved = false;
  String? _currentPrompt;
  DateTime? _readShownAt;
  bool _showSharpnessCheck = false;
  bool _sharpnessAnswered = false;
  bool _tooGenericFollowUp = false;
  String? _feedbackReadId;

  @override
  void initState() {
    super.initState();
    _bundle = _engine.build(
      widget.pattern,
      entry: widget.entry,
      priorEntries: widget.priorEntries,
      feedback: widget.feedback,
      selectedSignal: widget.selectedSignal,
      audienceWedge: widget.audienceWedge,
      activeLoop: widget.activeLoop,
      reflectionCount: widget.reflectionCount,
      categoryRepeated: widget.categoryRepeated,
    );
    _phase = _bundle.needsClearerMoment
        ? _PostSaveInsightPhase.allSignals
        : (_bundle.abPair != null
            ? _PostSaveInsightPhase.abChoice
            : _PostSaveInsightPhase.allSignals);
    _readShownAt = DateTime.now();
    if (_bundle.loopUnsupported && widget.activeLoop != null) {
      unawaited(LoopModeCoordinator.markUnsupportedRecording());
    }
  }

  Future<void> _recordInterpretation(
    PostSaveInsightSignal signal,
    ReadUserAction action,
  ) async {
    final prior = await InterpretationQualityStore.loadAll();
    final signalRecord = _qualityEngine.buildSignal(
      read: signal,
      bundle: _bundle,
      action: action,
      shownAt: _readShownAt,
      actedAt: DateTime.now(),
      priorSession: prior,
    );
    await InterpretationQualityStore.append(signalRecord);
  }

  void _offerSharpnessCheck(PostSaveInsightSignal signal) {
    if (widget.reflectionCount > 1) return;
    final readId = signal.readId ?? signal.id;
    if (_sharpnessAnswered) return;
    setState(() {
      _showSharpnessCheck = true;
      _feedbackReadId = readId;
    });
  }

  Future<void> _onSharpnessYesSpecific() async {
    final readId = _feedbackReadId;
    if (readId == null) return;
    await FirstInsightSpecificityStore.save(
      FirstInsightSpecificityRating.yesSpecific,
    );
    await InterpretationQualityStore.recordMicroFeedback(
      readId: readId,
      useful: true,
    );
    if (!mounted) return;
    setState(() {
      _sharpnessAnswered = true;
      _showSharpnessCheck = false;
    });
  }

  Future<void> _onSharpnessTooGeneric() async {
    final readId = _feedbackReadId;
    if (readId == null) return;
    await FirstInsightSpecificityStore.save(
      FirstInsightSpecificityRating.tooGeneric,
    );
    await InterpretationQualityStore.markSharpnessWeakness(readId: readId);
    if (_selected != null) {
      await _recordInterpretation(_selected!, ReadUserAction.rejected);
    }
    if (!mounted) return;
    setState(() {
      _sharpnessAnswered = true;
      _showSharpnessCheck = false;
      _tooGenericFollowUp = true;
      _phase = _PostSaveInsightPhase.allSignals;
    });
  }

  Future<void> _onSharpnessWrongAngle() async {
    final readId = _feedbackReadId;
    if (readId == null) return;
    await FirstInsightSpecificityStore.save(
      FirstInsightSpecificityRating.wrongAngle,
    );
    await InterpretationQualityStore.markSharpnessMismatch(readId: readId);
    if (!mounted) return;
    setState(() {
      _sharpnessAnswered = true;
      _showSharpnessCheck = false;
    });
    if (_selected != null) {
      _showAlternative(_selected!);
    }
  }

  Widget? _sharpnessWidget() {
    if (widget.reflectionCount > 1) {
      return _legacyMicroFeedbackWidget();
    }
    if (!_showSharpnessCheck || _sharpnessAnswered) return null;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: FirstInsightSharpnessRow(
        onYesSpecific: _onSharpnessYesSpecific,
        onTooGeneric: _onSharpnessTooGeneric,
        onWrongAngle: _onSharpnessWrongAngle,
      ),
    );
  }

  Widget? _legacyMicroFeedbackWidget() {
    return null;
  }

  FirstSessionPattern _patternForSignal(PostSaveInsightSignal signal) {
    if (signal.isPrimary || signal.categoryId == widget.pattern.categoryId) {
      return widget.pattern;
    }
    final alt = widget.pattern.alternativePatterns
        .where((a) => a.categoryId == signal.categoryId)
        .firstOrNull;
    if (alt == null) return widget.pattern;
    return widget.pattern.copyWith(
      title: alt.title,
      whyNoticed: alt.whyNoticed,
      watchForText: alt.watchForText,
      chips: alt.chips,
      categoryId: alt.categoryId,
      confidenceScore: alt.confidenceScore,
    );
  }

  List<String> _promptsFor(PostSaveInsightSignal signal) =>
      _promptEngine.promptsFor(
        signal: signal,
        pattern: widget.pattern,
        rotation: _promptRotation,
      );

  void _setPromptFor(PostSaveInsightSignal signal) {
    final prompts = _promptsFor(signal);
    _currentPrompt = prompts.isNotEmpty ? prompts.first : signal.recordNextQuestion;
  }

  Future<void> _persistSelection(PostSaveInsightSignal signal) async {
    await SelectedSignalCoordinator.save(
      title: signal.title,
      categoryId: signal.categoryId,
      strengthLabel: signal.strengthLabel ?? 'Early signal',
      nextPrompt: signal.recordNextQuestion,
      entryId: widget.entryId,
      whySuggested: signal.whySuggested,
      evidenceChips: signal.evidenceChips,
      mightMean: signal.mightMean,
      wouldConfirm: signal.wouldConfirm,
      wouldContradict: signal.wouldContradict,
      evidenceUsed: signal.evidenceUsed,
      readId: signal.readId,
    );
    await widget.onSaveSignal(_patternForSignal(signal));
  }

  Future<void> _finalizeSelection(
    PostSaveInsightSignal signal,
    PostSaveSignalAction action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SignalFeedbackCoordinator.track(
        action: action,
        signalId: signal.id,
        signalTitle: signal.title,
        entryId: widget.entryId,
        categoryId: signal.categoryId,
      );
      await _persistSelection(signal);
      await SignalJourneyCoordinator.onSignalAccepted(
        SignalJourneyAcceptInput(
          signalId: signal.id,
          signalTitle: signal.title,
          nextPrompt: signal.recordNextQuestion,
          readId: signal.readId,
          categoryId: signal.categoryId,
          entryId: widget.entryId,
          wouldConfirm: signal.wouldConfirm,
          wouldChallenge: signal.wouldContradict,
          evidenceSummary: signal.evidenceUsed,
        ),
      );
      if (action == PostSaveSignalAction.accepted && mounted) {
        unawaited(
          maybeOfferReminderPrePrompt(
            context,
            trigger: ReminderPrePromptTrigger.signalAccepted,
          ),
        );
      }
      if (!mounted) return;
      _setPromptFor(signal);
      setState(() {
        _busy = false;
        _selected = signal;
        _phase = _PostSaveInsightPhase.savedWithPrompt;
        _promptSaved = false;
      });
      _offerSharpnessCheck(signal);
      if (widget.activeLoop != null) {
        unawaited(LoopModeCoordinator.markReadAccepted());
      }
      unawaited(
        _recordInterpretation(signal, ReadUserAction.accepted),
      );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(PostSaveInsightSignal signal) async {
    await _finalizeSelection(signal, PostSaveSignalAction.accepted);
  }

  Future<void> _selectAb(
    PostSaveInsightSignal signal,
    PostSaveSignalAction action,
  ) async {
    await _finalizeSelection(signal, action);
  }

  void _abNeither() {
    unawaited(
      SignalFeedbackCoordinator.track(
        action: PostSaveSignalAction.abChoiceNeither,
        signalId: _bundle.abPair!.optionA.id,
        signalTitle: _bundle.abPair!.optionA.title,
        entryId: widget.entryId,
        categoryId: _bundle.abPair!.optionA.categoryId,
      ),
    );
    final alt = _engine.alternativeFor(
      bundle: _bundle,
      current: _bundle.abPair!.optionA,
      rotation: 0,
    );
    if (alt != null) {
      setState(() {
        _selected = alt;
        _phase = _PostSaveInsightPhase.alternative;
        _alternativeRotation = 1;
      });
    } else {
      setState(() => _phase = _PostSaveInsightPhase.allSignals);
    }
  }

  void _openDeeper(PostSaveInsightSignal signal) {
    unawaited(
      SignalFeedbackCoordinator.track(
        action: PostSaveSignalAction.deeperOpened,
        signalId: signal.id,
        signalTitle: signal.title,
        entryId: widget.entryId,
        categoryId: signal.categoryId,
      ),
    );
    unawaited(_recordInterpretation(signal, ReadUserAction.deeperOpened));
    setState(() {
      _selected = signal;
      _phase = _PostSaveInsightPhase.deeper;
    });
    _offerSharpnessCheck(signal);
  }

  void _showAlternative(PostSaveInsightSignal from) {
    unawaited(
      SignalFeedbackCoordinator.track(
        action: from.isPrimary
            ? PostSaveSignalAction.rejected
            : PostSaveSignalAction.anotherAngleShown,
        signalId: from.id,
        signalTitle: from.title,
        entryId: widget.entryId,
        categoryId: from.categoryId,
      ),
    );
    if (from.isPrimary) {
      unawaited(
        SignalJourneyCoordinator.onSignalRejected(
          signalId: from.id,
          readId: from.readId,
          categoryId: from.categoryId,
          signalTitle: from.title,
          entryId: widget.entryId,
        ),
      );
    }
    final next = _engine.alternativeFor(
      bundle: _bundle,
      current: from,
      rotation: _alternativeRotation,
      entry: widget.entry,
    );
    _alternativeRotation++;
    if (next == null) return;
    unawaited(_recordInterpretation(from, ReadUserAction.alternativeChosen));
    setState(() {
      _selected = next;
      _phase = _PostSaveInsightPhase.alternative;
      _readShownAt = DateTime.now();
    });
    _offerSharpnessCheck(next);
  }

  Future<void> _usePrompt() async {
    final prompt = _currentPrompt;
    if (prompt == null || prompt.isEmpty) return;
    await widget.onUsePrompt?.call(prompt);
    if (!mounted) return;
    setState(() => _promptSaved = true);
    final journey = await SignalJourneyCoordinator.loadActive();
    if (journey != null) {
      unawaited(
        NextEvidenceReminderService.schedule(
          journeyId: journey.id,
          prompt: prompt,
        ),
      );
    }
    if (mounted) {
      unawaited(
        maybeOfferReminderPrePrompt(
          context,
          trigger: ReminderPrePromptTrigger.nextEvidenceSaved,
        ),
      );
    }
  }

  void _cyclePrompt() {
    setState(() {
      _promptRotation++;
      if (_selected != null) {
        final prompts = _promptsFor(_selected!);
        _currentPrompt = prompts.isNotEmpty
            ? prompts.first
            : _selected!.recordNextQuestion;
      }
    });
  }

  Future<void> _recordNextEvidence(PostSaveInsightSignal? signal) async {
    final prompt = _currentPrompt ?? signal?.recordNextQuestion;
    if (prompt != null && prompt.isNotEmpty) {
      unawaited(
        SignalFeedbackCoordinator.track(
          action: PostSaveSignalAction.nextEvidenceChosen,
          signalId: signal?.id ?? 'next_prompt',
          signalTitle: signal?.title ?? prompt,
          entryId: widget.entryId,
          categoryId: signal?.categoryId,
        ),
      );
      widget.onRecordNextEvidence?.call(prompt);
      final journey = await SignalJourneyCoordinator.loadActive();
      if (journey != null) {
        unawaited(
          NextEvidenceReminderService.schedule(
            journeyId: journey.id,
            prompt: prompt,
          ),
        );
      }
      if (mounted) {
        unawaited(
          maybeOfferReminderPrePrompt(
            context,
            trigger: ReminderPrePromptTrigger.nextEvidenceSaved,
          ),
        );
      }
    }
    widget.onRecordNext();
  }

  @override
  Widget build(BuildContext context) {
    return ArchiveResponsiveLayout.constrainContent(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MomentsProgress(count: widget.reflectionCount),
          const SizedBox(height: AppSpacing.sm),
          if (_bundle.needsClearerMoment || _tooGenericFollowUp) ...[
            PostSaveClearerMomentBanner(
              title: _tooGenericFollowUp
                  ? null
                  : _bundle.clearerMomentTitle,
              prompt: _tooGenericFollowUp
                  ? ConsumerUiCopy.firstInsightTooGenericPrompt
                  : (_bundle.clearerMomentPrompt ??
                      ConsumerUiCopy.firstInsightTooGenericPrompt),
              onRecordNext: widget.onRecordNext,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          switch (_phase) {
            _PostSaveInsightPhase.abChoice => _AbChoiceView(
                pair: _bundle.abPair!,
                activeLoop: widget.activeLoop,
                isFirstInsight: widget.reflectionCount <= 1,
                titleSeed: widget.entryId?.hashCode ?? widget.reflectionCount,
                busy: _busy,
                onSelectA: () => _selectAb(
                  _bundle.abPair!.optionA,
                  PostSaveSignalAction.abChoiceA,
                ),
                onSelectB: () => _selectAb(
                  _bundle.abPair!.optionB,
                  PostSaveSignalAction.abChoiceB,
                ),
                onNeither: _abNeither,
              ),
            _PostSaveInsightPhase.allSignals => _ChoiceView(
                bundle: _bundle,
                isFirstInsight: widget.reflectionCount <= 1,
                titleSeed: widget.entryId?.hashCode ?? widget.reflectionCount,
                onFeelsTrue: _save,
                onNotQuite: _showAlternative,
                onGoDeeper: _openDeeper,
                busy: _busy,
              ),
            _PostSaveInsightPhase.deeper => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GoDeeperView(
                    signal: _selected!,
                    busy: _busy,
                    onSave: () => _save(_selected!),
                    onAnotherAngle: () => _showAlternative(_selected!),
                    onRecordNext: () => _recordNextEvidence(_selected),
                    onBack: () => setState(
                      () => _phase = _selected != null &&
                              _phase == _PostSaveInsightPhase.deeper &&
                              _bundle.abPair != null
                          ? _PostSaveInsightPhase.savedWithPrompt
                          : _PostSaveInsightPhase.allSignals,
                    ),
                  ),
                  if (_sharpnessWidget() != null) _sharpnessWidget()!,
                ],
              ),
            _PostSaveInsightPhase.alternative => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AlternativeView(
                    signal: _selected!,
                    busy: _busy,
                    onFeelsTrue: () => _save(_selected!),
                    onAnotherAngle: () => _showAlternative(_selected!),
                    onGoDeeper: () =>
                        setState(() => _phase = _PostSaveInsightPhase.deeper),
                    onBack: () => setState(
                      () => _phase = _bundle.abPair != null
                          ? _PostSaveInsightPhase.abChoice
                          : _PostSaveInsightPhase.allSignals,
                    ),
                    onRecordNext: () => _recordNextEvidence(_selected),
                  ),
                  if (_sharpnessWidget() != null) _sharpnessWidget()!,
                ],
              ),
            _PostSaveInsightPhase.savedWithPrompt => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SavedWithPromptView(
                    signal: _selected!,
                    prompt: _currentPrompt ?? _selected!.recordNextQuestion,
                    promptSaved: _promptSaved,
                    onGoDeeper: () => _openDeeper(_selected!),
                    onUsePrompt: _usePrompt,
                    onChooseAnother: _cyclePrompt,
                    onRecordNext: () => _recordNextEvidence(_selected),
                    onViewPatterns: widget.onViewPatterns,
                    onViewSignalDetail: () =>
                        SignalArchiveNavigation.openSignalDetail(context),
                    onViewEvidenceTrail: () =>
                        SignalArchiveNavigation.openEvidenceTrail(context),
                  ),
                  if (_sharpnessWidget() != null) _sharpnessWidget()!,
                ],
              ),
          },
          if (_showProveEnoughPayoff) ...[
            const SizedBox(height: AppSpacing.sm),
            ProveEnoughPostRecordPayoff(
              entryId: widget.entryId ?? widget.entry!.id,
              entry: widget.entry!,
              activeLoop: widget.activeLoop!,
              pattern: widget.pattern,
              priorEntries: widget.priorEntries,
              feedback: widget.feedback,
              selectedSignal: widget.selectedSignal,
              audienceWedge: widget.audienceWedge,
            ),
          ],
        ],
      ),
    );
  }

  bool get _showProveEnoughPayoff =>
      widget.activeLoop?.isProveEnough == true && widget.entry != null;
}

class _MomentsProgress extends StatelessWidget {
  const _MomentsProgress({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final clamped = count.clamp(1, 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ConsumerUiCopy.postSaveInsightMomentsProgress
              .replaceAll('{count}', clamped.toString()),
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: List.generate(3, (i) {
            final filled = i < clamped;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  color: filled
                      ? AppColors.accentPrimary
                      : AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _AbChoiceView extends StatelessWidget {
  const _AbChoiceView({
    required this.pair,
    required this.activeLoop,
    required this.isFirstInsight,
    required this.titleSeed,
    required this.onSelectA,
    required this.onSelectB,
    required this.onNeither,
    required this.busy,
  });

  final AbReadPair pair;
  final LoopMode? activeLoop;
  final bool isFirstInsight;
  final int titleSeed;
  final VoidCallback onSelectA;
  final VoidCallback onSelectB;
  final VoidCallback onNeither;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final loopEngine = const LoopModeEngine();
    final loopActive = activeLoop?.isFullyImplementedLoop == true;
    final title = loopActive
        ? loopEngine.postSaveTitle(activeLoop!)
        : (isFirstInsight
            ? ConsumerUiCopy.firstInsightChoiceTitleFor(titleSeed)
            : ConsumerUiCopy.postSaveInsightAbChoiceTitle);
    final subtitle = loopActive
        ? loopEngine.postSaveSubtitle(activeLoop!)
        : (isFirstInsight ? ConsumerUiCopy.firstInsightDisclaimer : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: ArchiveMobileTypography.responsivePageTitle(context),
        ),
        if (subtitle != null) ...[
          SizedBox(height: gap),
          Text(
            subtitle,
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              fontStyle: loopActive ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
        SizedBox(height: gap),
        Text(
          ConsumerUiCopy.postSaveInsightAbChoiceTitle,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        SizedBox(height: gap),
        _AbOptionCard(
          label: 'A',
          signal: pair.optionA,
          accent: true,
        ),
        SizedBox(height: gap),
        _AbOptionCard(label: 'B', signal: pair.optionB),
        SizedBox(height: gap),
        FilledButton(
          onPressed: busy ? null : onSelectA,
          child: Text(ConsumerUiCopy.postSaveInsightAbFeelsCloserA),
        ),
        const SizedBox(height: AppSpacing.xs),
        FilledButton(
          onPressed: busy ? null : onSelectB,
          child: Text(ConsumerUiCopy.postSaveInsightAbFeelsCloserB),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: busy ? null : onNeither,
          child: Text(ConsumerUiCopy.postSaveInsightAbNeither),
        ),
      ],
    );
  }
}

class _AbOptionCard extends StatelessWidget {
  const _AbOptionCard({
    required this.label,
    required this.signal,
    this.accent = false,
  });

  final String label;
  final PostSaveInsightSignal signal;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final decoration = accent
        ? VoiceMemoryCards.standard(
            background: AppColors.accentPrimary.withValues(alpha: 0.08),
          ).copyWith(
            border: Border.all(
              color: AppColors.accentPrimary.withValues(alpha: 0.35),
            ),
          )
        : VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5));

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$label. ${signal.title}',
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StrengthSection(signal: signal),
          if (signal.explanation.isNotEmpty) ...[
            SizedBox(height: gap),
            Text(
              signal.explanation,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _StrengthSection extends StatelessWidget {
  const _StrengthSection({required this.signal});

  final PostSaveInsightSignal signal;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (signal.strengthLabel != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              signal.strengthLabel!,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
          ),
          SizedBox(height: gap / 2),
        ],
        Text(
          ConsumerUiCopy.postSaveInsightWhySuggested,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          signal.whySuggested ?? signal.explanation,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        if (signal.evidenceChips.isNotEmpty) ...[
          SizedBox(height: gap / 2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final chip in signal.evidenceChips)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    chip,
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChoiceView extends StatelessWidget {
  const _ChoiceView({
    required this.bundle,
    required this.isFirstInsight,
    required this.titleSeed,
    required this.onFeelsTrue,
    required this.onNotQuite,
    required this.onGoDeeper,
    required this.busy,
  });

  final PostSaveInsightBundle bundle;
  final bool isFirstInsight;
  final int titleSeed;
  final ValueChanged<PostSaveInsightSignal> onFeelsTrue;
  final ValueChanged<PostSaveInsightSignal> onNotQuite;
  final ValueChanged<PostSaveInsightSignal> onGoDeeper;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final title = isFirstInsight
        ? ConsumerUiCopy.firstInsightChoiceTitleFor(titleSeed)
        : ConsumerUiCopy.postSaveInsightChoiceTitle;
    final lead = isFirstInsight
        ? ConsumerUiCopy.firstInsightChoiceLead
        : ConsumerUiCopy.postSaveInsightChoiceLead;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: ArchiveMobileTypography.responsivePageTitle(context),
        ),
        SizedBox(height: gap),
        Text(
          lead,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        if (isFirstInsight) ...[
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.firstInsightDisclaimer,
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        SizedBox(height: gap),
        for (final signal in bundle.signals) ...[
          _SignalCard(
            signal: signal,
            busy: busy,
            accent: signal.isPrimary,
            isFirstInsight: isFirstInsight,
            onFeelsTrue: () => onFeelsTrue(signal),
            onNotQuite: () => onNotQuite(signal),
            onGoDeeper: () => onGoDeeper(signal),
          ),
          SizedBox(height: gap),
        ],
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.signal,
    required this.onFeelsTrue,
    required this.onNotQuite,
    required this.onGoDeeper,
    required this.busy,
    this.accent = false,
    this.isFirstInsight = false,
  });

  final PostSaveInsightSignal signal;
  final VoidCallback onFeelsTrue;
  final VoidCallback onNotQuite;
  final VoidCallback onGoDeeper;
  final bool busy;
  final bool accent;
  final bool isFirstInsight;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final decoration = accent
        ? VoiceMemoryCards.standard(
            background: AppColors.accentPrimary.withValues(alpha: 0.08),
          ).copyWith(
            border: Border.all(
              color: AppColors.accentPrimary.withValues(alpha: 0.35),
            ),
          )
        : VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5));

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isFirstInsight) ...[
            Text(
              ConsumerUiCopy.firstInsightPossibleLoop,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            signal.title,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StrengthSection(signal: signal),
          if (signal.evidenceLine != null || signal.evidenceUsed != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              isFirstInsight
                  ? ConsumerUiCopy.firstInsightEvidenceUsed
                  : ConsumerUiCopy.postSaveInsightEvidenceFromMoment,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              signal.evidenceUsed?.trim().isNotEmpty == true
                  ? signal.evidenceUsed!
                  : (signal.evidenceLine ?? ''),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          if (isFirstInsight &&
              signal.wouldConfirm.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ConsumerUiCopy.firstInsightWouldConfirm,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              signal.wouldConfirm,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          if (isFirstInsight &&
              signal.wouldContradict.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ConsumerUiCopy.firstInsightWouldContradict,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              signal.wouldContradict,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          if (isFirstInsight &&
              signal.recordNextQuestion.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              ConsumerUiCopy.firstInsightNextEvidence,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              signal.recordNextQuestion,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          SizedBox(height: gap),
          FilledButton(
            onPressed: busy ? null : onFeelsTrue,
            child: Text(ConsumerUiCopy.postSaveInsightFeelsTrue),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onNotQuite,
                  child: Text(ConsumerUiCopy.postSaveInsightNotMe),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onGoDeeper,
                  child: Text(ConsumerUiCopy.postSaveInsightGoDeeper),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoDeeperView extends StatelessWidget {
  const _GoDeeperView({
    required this.signal,
    required this.onSave,
    required this.onAnotherAngle,
    required this.onRecordNext,
    required this.onBack,
    required this.busy,
  });

  final PostSaveInsightSignal signal;
  final VoidCallback onSave;
  final VoidCallback onAnotherAngle;
  final VoidCallback onRecordNext;
  final VoidCallback onBack;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    return _InsightPanel(
      title: signal.title,
      onBack: onBack,
      strength: signal,
      sections: [
        _Section(
          label: ConsumerUiCopy.postSaveInsightMightMean,
          body: signal.mightMean,
        ),
        if (signal.evidenceUsed?.trim().isNotEmpty == true)
          _Section(
            label: ConsumerUiCopy.postSaveInsightEvidenceUsed,
            body: signal.evidenceUsed!,
          ),
        _Section(
          label: ConsumerUiCopy.postSaveInsightWouldConfirm,
          body: signal.wouldConfirm,
        ),
        _Section(
          label: ConsumerUiCopy.postSaveInsightWouldContradict,
          body: signal.wouldContradict,
        ),
        _Section(
          label: ConsumerUiCopy.postSaveInsightRecordNext,
          body: signal.recordNextQuestion,
        ),
      ],
      actions: [
        FilledButton(
          onPressed: busy ? null : onSave,
          child: Text(ConsumerUiCopy.postSaveInsightSaveSignal),
        ),
        SizedBox(height: gap),
        OutlinedButton(
          onPressed: busy ? null : onAnotherAngle,
          child: Text(ConsumerUiCopy.postSaveInsightAnotherAngle),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: busy ? null : onRecordNext,
          child: Text(ConsumerUiCopy.postSaveInsightRecordNextEvidence),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => SignalArchiveNavigation.openEvidenceTrail(context),
          child: Text(ConsumerUiCopy.signalDetailViewEvidenceTrail),
        ),
      ],
    );
  }
}

class _AlternativeView extends StatelessWidget {
  const _AlternativeView({
    required this.signal,
    required this.onFeelsTrue,
    required this.onAnotherAngle,
    required this.onGoDeeper,
    required this.onRecordNext,
    required this.onBack,
    required this.busy,
  });

  final PostSaveInsightSignal signal;
  final VoidCallback onFeelsTrue;
  final VoidCallback onAnotherAngle;
  final VoidCallback onGoDeeper;
  final VoidCallback onRecordNext;
  final VoidCallback onBack;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    return _InsightPanel(
      title: ConsumerUiCopy.postSaveInsightAlternativeTitle,
      onBack: onBack,
      strength: signal,
      sections: [
        _Section(
          label: ConsumerUiCopy.postSaveInsightAlternativeLead,
          body: '',
          isLead: true,
        ),
        _Section(label: signal.title, body: signal.explanation, isTitle: true),
        _Section(
          label: ConsumerUiCopy.postSaveInsightMightMean,
          body: signal.mightMean,
        ),
      ],
      actions: [
        FilledButton(
          onPressed: busy ? null : onFeelsTrue,
          child: Text(ConsumerUiCopy.postSaveInsightFeelsTrue),
        ),
        SizedBox(height: gap),
        OutlinedButton(
          onPressed: busy ? null : onAnotherAngle,
          child: Text(ConsumerUiCopy.postSaveInsightAnotherAngle),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: busy ? null : onGoDeeper,
          child: Text(ConsumerUiCopy.postSaveInsightGoDeeper),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: busy ? null : onRecordNext,
          child: Text(ConsumerUiCopy.postSaveInsightRecordNextEvidence),
        ),
      ],
    );
  }
}

class _SavedWithPromptView extends StatelessWidget {
  const _SavedWithPromptView({
    required this.signal,
    required this.prompt,
    required this.promptSaved,
    required this.onGoDeeper,
    required this.onUsePrompt,
    required this.onChooseAnother,
    required this.onRecordNext,
    this.onViewPatterns,
    this.onViewSignalDetail,
    this.onViewEvidenceTrail,
  });

  final PostSaveInsightSignal signal;
  final String prompt;
  final bool promptSaved;
  final VoidCallback onGoDeeper;
  final VoidCallback onUsePrompt;
  final VoidCallback onChooseAnother;
  final VoidCallback onRecordNext;
  final VoidCallback? onViewPatterns;
  final VoidCallback? onViewSignalDetail;
  final VoidCallback? onViewEvidenceTrail;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: ArchiveResponsiveLayout.cardInsets(context),
          decoration: VoiceMemoryCards.standard(
            background: const Color(0xFFFFFBF5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      ConsumerUiCopy.postSaveInsightSavedAck,
                      style: ArchiveMobileTypography.explanationBody(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ConsumerUiCopy.postSaveInsightUseAsEvidence,
                style: ArchiveMobileTypography.explanationBody(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                signal.title,
                style: ArchiveMobileTypography.listTitle(context),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        NextEvidencePromptCard(
          prompt: prompt,
          onUsePrompt: onUsePrompt,
          onChooseAnother: onChooseAnother,
        ),
        if (promptSaved) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.check, size: 18, color: AppColors.success),
              const SizedBox(width: AppSpacing.xs),
              Text(
                ConsumerUiCopy.postSaveInsightNextPromptSaved,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
            ],
          ),
        ],
        SizedBox(height: gap),
        if (onViewSignalDetail != null)
          FilledButton.tonal(
            onPressed: onViewSignalDetail,
            child: Text(ConsumerUiCopy.signalDetailViewSignal),
          ),
        if (onViewSignalDetail != null) SizedBox(height: gap),
        OutlinedButton(
          onPressed: onGoDeeper,
          child: Text(ConsumerUiCopy.postSaveInsightGoDeeper),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: onRecordNext,
          child: Text(ConsumerUiCopy.postSaveInsightRecordNextEvidence),
        ),
        if (onViewEvidenceTrail != null) ...[
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onViewEvidenceTrail,
            child: Text(ConsumerUiCopy.signalDetailViewEvidenceTrail),
          ),
        ],
        if (onViewPatterns != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onViewPatterns,
            child: Text(ConsumerUiCopy.viewPatternsCta),
          ),
        ],
      ],
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({
    required this.title,
    required this.onBack,
    required this.sections,
    required this.actions,
    this.strength,
  });

  final String title;
  final VoidCallback onBack;
  final List<_Section> sections;
  final List<Widget> actions;
  final PostSaveInsightSignal? strength;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(ConsumerUiCopy.back),
          ),
        ),
        Text(
          title,
          style: ArchiveMobileTypography.responsiveSectionTitle(context),
        ),
        if (strength != null) ...[
          SizedBox(height: gap),
          _StrengthSection(signal: strength!),
        ],
        SizedBox(height: gap),
        for (final section in sections) ...[
          if (section.isLead)
            Text(
              section.label,
              style: ArchiveMobileTypography.responsiveBody(context),
            )
          else if (section.isTitle)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.label,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  section.body,
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
              ],
            )
          else ...[
            Text(
              section.label,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              section.body,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          SizedBox(height: gap),
        ],
        ...actions,
      ],
    );
  }
}

class _Section {
  const _Section({
    required this.label,
    required this.body,
    this.isLead = false,
    this.isTitle = false,
  });

  final String label;
  final String body;
  final bool isLead;
  final bool isTitle;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
