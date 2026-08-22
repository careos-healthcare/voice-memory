part of 'recording_screen.dart';

extension RecordingBuildContextResolver on _RecordScreenState {
  RecordBuildContext assembleRecordBuildContext(BuildContext context) {
    final input = _buildRecordSurfaceInput();
    final view = _recordSurfaceResolutionNotifier.resolve(input);

    final stack = view.stack;
    if (stack.showFirstRecordingHandoff && !_firstRecordCardTracked) {
      _firstRecordCardTracked = true;
      unawaited(ActivationTracker.trackActivationFirstRecordCardShown());
    }

    final ui = input.ui;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showFirstSessionOnboarding =
        view.showFraming &&
        ui == RecordUiState.ready &&
        _journalEntryCountReady &&
        !view.showReturningWatchTargetFocusedUi &&
        FirstSessionOnboardingStore.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: ui == RecordUiState.ready,
          isPostSave: _isPostSaveSurface,
        );
    final showFirstUseWordingHelper =
        ui == RecordUiState.ready &&
        FirstUseWordingGates.shouldShow(
          loaded: _journalEntryCountReady,
          entryCount: _journalEntryCount,
          isReady: true,
          isPostSave: _isPostSaveSurface,
          isRecordCluttered: _isPostSaveSurface,
        );
    final showCloseButton = RecordScreenCloseButton.shouldShow(context);

    return RecordBuildContextAdapter.fromViewState(
      view,
      chrome: RecordBuildContextChrome(
        ui: ui,
        bottomInset: bottomInset,
        showFirstSessionOnboarding: showFirstSessionOnboarding,
        showFirstUseWordingHelper: showFirstUseWordingHelper,
        showCloseButton: showCloseButton,
      ),
    );
  }
}
