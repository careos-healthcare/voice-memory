import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/feedback/archive_feedback_model.dart';
import '../../features/routine/routine_anchor_model.dart';
import '../../features/tomorrow_return/compelling_check_engine.dart';
import '../../features/tomorrow_return/compelling_check_model.dart';
import '../../features/tomorrow_return/result_next_check_engine.dart';
import '../../features/tomorrow_return/result_next_check_model.dart';
import '../../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../../features/tomorrow_return/tomorrow_check_in_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';
import '../feedback/archive_feedback_chips.dart';
import '../tomorrow_return/compelling_check_preview.dart';

/// Turns a closed-loop result into one useful next check.
///
/// Shown after [CheckInCompletedCard] when the loop is closed. The primary
/// action locks in tomorrow's check with the suggested question; the secondary
/// action lets the user pick a different check.
class ResultNextCheckCard extends StatefulWidget {
  const ResultNextCheckCard({
    super.key,
    required this.checkIn,
    this.notUsefulReason,
    this.onCreateCheckIn,
    this.routineAnchorPicker,
    this.onRoutineAnchorChosen,
    this.feedbackHint,
    this.showFeedback = true,
    this.preferDirect = false,
  });

  final TomorrowCheckIn checkIn;

  /// Most recent "not useful" complaint, used to sharpen the next check.
  final String? notUsefulReason;

  /// The dominant feedback correction so far. Gently nudges the next check
  /// (e.g. "Too generic" prefers a concrete, single-moment question).
  final ArchiveFeedbackType? feedbackHint;

  /// When false, the feedback chips row is hidden — used when this card is
  /// embedded inside another card that already shows one feedback row.
  final bool showFeedback;

  /// Sharper default when the user previously ignored or did not care.
  final bool preferDirect;

  /// Creates tomorrow's check-in for [question]. Defaults to the coordinator;
  /// injectable so widget tests never touch storage.
  final Future<void> Function(String question)? onCreateCheckIn;

  /// Optional chooser shown after locking in the check, letting the user attach
  /// it to a routine moment. Returns the chosen anchor, or null if skipped.
  final Future<RoutineAnchor?> Function()? routineAnchorPicker;

  /// Persists the chosen routine anchor for tomorrow's check.
  final Future<void> Function(RoutineAnchor anchor)? onRoutineAnchorChosen;

  @override
  State<ResultNextCheckCard> createState() => _ResultNextCheckCardState();
}

class _ResultNextCheckCardState extends State<ResultNextCheckCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  bool _busy = false;
  bool _done = false;
  late String _selectedSharpness;
  late CompellingCheckQuestion _selectedCheck;

  String get _resultHint => widget.checkIn.selectedOptionId ?? 'same';

  ResultNextCheck get _nextCheck => ResultNextCheckEngine.build(
    resultHint: _resultHint,
    checkInQuestion: widget.checkIn.question,
    notUsefulReason: widget.notUsefulReason,
    patternTitle: widget.checkIn.patternTitle,
    feedback: widget.feedbackHint,
    preferDirect: widget.preferDirect,
  );

  Map<String, CompellingCheckQuestion> get _options =>
      ResultNextCheckEngine.compellingOptions(
        resultHint: _resultHint,
        checkInQuestion: widget.checkIn.question,
        patternTitle: widget.checkIn.patternTitle,
        feedback: widget.feedbackHint,
        preferDirect: widget.preferDirect,
      );

  @override
  void initState() {
    super.initState();
    _selectedSharpness = defaultCompellingSharpnessLabel(
      feedback: widget.feedbackHint,
      preferDirect: widget.preferDirect,
    );
    _selectedCheck =
        _options[_selectedSharpness] ??
        CompellingCheckQuestion(
          type: CompellingCheckType.repeatMoment,
          question: _nextCheck.nextQuestion,
          whyThisCheck: _nextCheck.whyUseful,
          exampleAnswer: _nextCheck.exampleMoment,
          sharpnessLabel: _selectedSharpness,
        );
    ActivationTracker.trackResultNextCheckShown();
    ActivationTracker.trackActivationNextCheckShown();
  }

  @override
  void didUpdateWidget(covariant ResultNextCheckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkIn.id != widget.checkIn.id ||
        oldWidget.feedbackHint != widget.feedbackHint) {
      _selectedSharpness = defaultCompellingSharpnessLabel(
        feedback: widget.feedbackHint,
        preferDirect: widget.preferDirect,
      );
      _selectedCheck = _options[_selectedSharpness] ?? _selectedCheck;
    }
  }

  void _onSharpnessSelected(CompellingCheckQuestion option) {
    setState(() {
      _selectedSharpness = option.sharpnessLabel;
      _selectedCheck = option;
    });
  }

  Future<void> _create(String question) async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    final create = widget.onCreateCheckIn ?? _defaultCreate;
    await create(question);
    await _maybePlanRoutineAnchor();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
  }

  Future<void> _maybePlanRoutineAnchor() async {
    final picker = widget.routineAnchorPicker;
    if (picker == null) return;
    ActivationTracker.trackActivationRoutineAnchorOffered();
    final anchor = await picker();
    if (anchor == null) return;
    await widget.onRoutineAnchorChosen?.call(anchor);
    ActivationTracker.trackActivationRoutineAnchorSet();
  }

  Future<void> _defaultCreate(String question) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: widget.checkIn.patternTitle,
      specificPrompt: widget.checkIn.prompt,
      checkInQuestion: question,
    );
  }

  Future<void> _onUseThis() async {
    ActivationTracker.trackResultNextCheckUsed();
    ActivationTracker.trackActivationNextCheckUsed();
    ActivationTracker.trackCompellingCheckAccepted();
    await _create(_selectedCheck.question);
  }

  Future<void> _onChooseDifferent() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _warmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ConsumerUiCopy.resultNextCheckChooseSheetTitle,
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _altTile(sheetContext, ConsumerUiCopy.resultNextCheckAltBefore),
              _altTile(sheetContext, ConsumerUiCopy.resultNextCheckAltHelped),
              _altTile(sheetContext, ConsumerUiCopy.resultNextCheckAltHeavier),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    ActivationTracker.trackResultNextCheckChanged();
    ActivationTracker.trackActivationNextCheckChanged();
    ActivationTracker.trackCompellingCheckAccepted();
    await _create(picked);
  }

  Widget _altTile(BuildContext sheetContext, String question) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        question,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 15, height: 1.4),
      ),
      onTap: () => Navigator.of(sheetContext).pop(question),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextCheck;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.resultNextCheckTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            next.title,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.md),
          CompellingCheckPreview(
            check: _selectedCheck,
            options: _options,
            selectedSharpnessLabel: _selectedSharpness,
            onSharpnessSelected: _done ? null : _onSharpnessSelected,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_done)
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    ConsumerUiCopy.resultNextCheckConfirmation,
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.success,
                    ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: _busy ? null : _onUseThis,
                child: const Text(ConsumerUiCopy.resultNextCheckUseTomorrowCta),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy ? null : _onChooseDifferent,
                child: const Text(
                  ConsumerUiCopy.resultNextCheckChooseDifferentCta,
                ),
              ),
            ),
          ],
          if (widget.showFeedback)
            ArchiveFeedbackChips(
              targetType: ArchiveFeedbackTargetType.nextCheck,
              targetId: widget.checkIn.id,
              patternTitle: widget.checkIn.patternTitle,
              resultHint: widget.checkIn.selectedOptionId,
            ),
        ],
      ),
    );
  }
}
