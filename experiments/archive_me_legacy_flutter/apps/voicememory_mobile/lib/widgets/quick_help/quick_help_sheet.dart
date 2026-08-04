import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/language/localized_copy.dart';
import '../../features/quick_help/quick_help_engine.dart';
import '../../features/quick_help/quick_help_model.dart';
import '../../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Opens the guided "Quick help" sheet — a safety valve that gives one
/// practical next step. Not an open chat: the user picks from five fixed
/// intents and gets a single grounded response.
Future<void> showQuickHelpSheet(
  BuildContext context, {
  String languageCode = 'en',
  String? latestReflectionText,
  String? patternTitle,
  String? resultHint,
  String? nextCheck,
  required Future<void> Function() onStartRecording,
  Future<void> Function(String question)? onUseCheck,
  VoidCallback? onShowPerspective,
  QuickHelpIntent? initialIntent,
}) {
  ActivationTracker.trackQuickHelpOpened();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => QuickHelpSheet(
      languageCode: languageCode,
      latestReflectionText: latestReflectionText,
      patternTitle: patternTitle,
      resultHint: resultHint,
      nextCheck: nextCheck,
      onStartRecording: onStartRecording,
      onUseCheck: onUseCheck,
      onShowPerspective: onShowPerspective,
      initialIntent: initialIntent,
    ),
  );
}

class QuickHelpSheet extends StatefulWidget {
  const QuickHelpSheet({
    super.key,
    this.languageCode = 'en',
    this.latestReflectionText,
    this.patternTitle,
    this.resultHint,
    this.nextCheck,
    required this.onStartRecording,
    this.onUseCheck,
    this.onShowPerspective,
    this.initialIntent,
  });

  final String languageCode;
  final String? latestReflectionText;
  final String? patternTitle;
  final String? resultHint;
  final String? nextCheck;
  final Future<void> Function() onStartRecording;
  final Future<void> Function(String question)? onUseCheck;
  final VoidCallback? onShowPerspective;
  final QuickHelpIntent? initialIntent;

  @override
  State<QuickHelpSheet> createState() => _QuickHelpSheetState();
}

class _QuickHelpSheetState extends State<QuickHelpSheet> {
  static const Color _warmSurface = Color(0xFFFFFBF5);

  QuickHelpResponse? _response;
  bool _busy = false;
  bool _done = false;

  String _t(String key) => localized(key, widget.languageCode);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIntent;
    if (initial != null) {
      _response = buildQuickHelpResponse(
        intent: initial,
        latestReflectionText: widget.latestReflectionText,
        patternTitle: widget.patternTitle,
        resultHint: widget.resultHint,
        nextCheck: widget.nextCheck,
      );
    }
  }

  static const List<QuickHelpIntent> _intents = [
    QuickHelpIntent.whatToRecord,
    QuickHelpIntent.anotherPerspective,
    QuickHelpIntent.practicalNextStep,
    QuickHelpIntent.kinderAngle,
    QuickHelpIntent.whatToCheckNext,
  ];

  String _intentLabel(QuickHelpIntent intent) {
    switch (intent) {
      case QuickHelpIntent.whatToRecord:
        return _t('quickHelpWhatToRecord');
      case QuickHelpIntent.anotherPerspective:
        return _t('quickHelpAnotherPerspective');
      case QuickHelpIntent.practicalNextStep:
        return _t('quickHelpPractical');
      case QuickHelpIntent.kinderAngle:
        return _t('quickHelpHardOnMyself');
      case QuickHelpIntent.whatToCheckNext:
        return _t('quickHelpWhatToCheck');
    }
  }

  String _actionLabel(QuickHelpAction action) {
    switch (action) {
      case QuickHelpAction.startRecording:
        return _t('startRecording');
      case QuickHelpAction.useThisCheck:
        return _t('useThisCheck');
      case QuickHelpAction.showPerspective:
        return _t('showPerspective');
    }
  }

  void _selectIntent(QuickHelpIntent intent) {
    ActivationTracker.trackQuickHelpIntentSelected();
    setState(() {
      _response = buildQuickHelpResponse(
        intent: intent,
        latestReflectionText: widget.latestReflectionText,
        patternTitle: widget.patternTitle,
        resultHint: widget.resultHint,
        nextCheck: widget.nextCheck,
      );
      _done = false;
    });
  }

  void _backToOptions() {
    setState(() {
      _response = null;
      _done = false;
    });
  }

  Future<void> _onPrimary(QuickHelpResponse response) async {
    if (_busy || _done) return;
    ActivationTracker.trackQuickHelpPrimaryActionTapped();
    switch (response.action) {
      case QuickHelpAction.startRecording:
        Navigator.of(context).maybePop();
        await widget.onStartRecording();
        return;
      case QuickHelpAction.showPerspective:
        if (widget.onShowPerspective != null) {
          Navigator.of(context).maybePop();
          widget.onShowPerspective!.call();
          return;
        }
        setState(() => _done = true);
        return;
      case QuickHelpAction.useThisCheck:
        setState(() => _busy = true);
        ActivationTracker.trackQuickHelpCheckUsed();
        final question = response.nextCheck ?? response.body;
        final create = widget.onUseCheck ?? _defaultCreate;
        await create(question);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _done = true;
        });
        return;
    }
  }

  Future<void> _defaultCreate(String question) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: widget.patternTitle ?? '',
      specificPrompt: '',
      checkInQuestion: question,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: _warmSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _response == null ? _optionsView() : _responseView(_response!),
          ],
        ),
      ),
    );
  }

  Widget _optionsView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('needHelpNow'),
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 18),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _t('quickHelpSubtitle'),
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final intent in _intents) ...[
          _optionButton(intent),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }

  Widget _optionButton(QuickHelpIntent intent) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _selectIntent(intent),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          side: BorderSide(
            color: AppColors.accentPrimary.withValues(alpha: 0.35),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _intentLabel(intent),
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 15),
        ),
      ),
    );
  }

  Widget _responseView(QuickHelpResponse response) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          response.title,
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 18),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          response.body,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 16, height: 1.45),
        ),
        if (response.example != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_t('example')}: ${response.example}',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14, fontStyle: FontStyle.italic, height: 1.4),
          ),
        ],
        if (response.nextCheck != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_t('nextCheck')}: ${response.nextCheck}',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (_done)
          _confirmation(response)
        else ...[
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: _busy ? null : () => _onPrimary(response),
              child: Text(_actionLabel(response.action)),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _backToOptions,
              child: Text(_t('backToOptions')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _confirmation(QuickHelpResponse response) {
    final message = response.action == QuickHelpAction.useThisCheck
        ? _t('tomorrowCheckSet')
        : response.title;
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.success,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
