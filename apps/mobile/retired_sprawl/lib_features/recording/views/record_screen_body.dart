part of '../recording_screen.dart';

extension RecordScreenBody on _RecordScreenState {
  Widget _buildRecordScreenBody(BuildContext context, RecordBuildContext ctx) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: const Key('record_screen_scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            24,
            ctx.firstUseSimplifiedRecord ? 0 : 8,
            24,
            (ctx.compact ? 12.0 : 16.0) + ctx.bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: ctx.firstUseSimplifiedRecord
                  ? 0
                  : constraints.maxHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._buildRecordScreenBodyChildren(context, ctx),
                ..._buildBottomActions(
                  context,
                  ui: ctx.ui,
                  canRecord: ctx.canRecord,
                  localSaveTitle: ctx.localSaveTitle,
                  selectedPrompt: _selectedPromptLine,
                  suppressDuplicateRecordCtas:
                      ctx.stack.suppressDuplicateRecordCtas ||
                      ctx.suppressNoisyFirstSaveCards ||
                      (ctx.suppressNoisyRepeatPostSaveCards &&
                          !ctx.showWhatChangedV2 &&
                          !ctx.showWhatChangedV2Display) ||
                      ctx.showDegradedTranscriptFocusedPostSave,
                  showReturningWatchTargetFocusedUi:
                      ctx.showReturningWatchTargetFocusedUi,
                  policyMicPhase: ctx.policyMic,
                  policyUserDenied: ctx.policyUserDenied,
                  recordHomeSurface: ctx.recordHomeSurface,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
