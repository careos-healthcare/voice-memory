part of '../recording_screen.dart';

extension RecordingCaptureActionsWidget on _RecordScreenState {
  Widget _buildCaptureEntryActions({
    required BuildContext context,
    required String? selectedPrompt,
    required RecordCtaPolicyResolution policy,
    bool suppressLogPressureMoment = false,
  }) {
    return CaptureEntryActions(
      onRecord: () => unawaited(_onRecordPressed(source: 'main')),
      recordButtonKey: const Key('capture_entry_record_cta'),
      typeCapturePrompt: BetaImprovementPackEngine.typedCapturePrompt(
        fallback: selectedPrompt ?? '',
      ),
      onTextThoughtSaved: _finishSuccessfulCapture,
      onLogPressureMoment: suppressLogPressureMoment
          ? null
          : () => context.push('/pressure-check-in'),
      pressureMomentPresentation: suppressLogPressureMoment
          ? CapturePressureMomentPresentation.none
          : CapturePressureMomentPresentation.button,
      recordButtonLabel: _recordEntryCtaLabel(policy),
      underRecordHelper: null,
      preferTypedFirst: BetaImprovementPackEngine.preferTypedCaptureFirst(
        entryCount: _journalEntryCount,
      ),
    );
  }
}
