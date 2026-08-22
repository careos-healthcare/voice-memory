part of '../recording_screen.dart';

extension RecordingPermissionPanel on _RecordScreenState {
  Widget _buildRecordingPermissionPanel(
    BuildContext context,
    RecordBuildContext ctx,
  ) {
    return AnimatedSwitcher(
        key: const Key(
          'microphone_recovery_animated_switcher',
        ),
        duration: const Duration(milliseconds: 280),
        reverseDuration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                child: child,
              ),
            ),
        child:
            RecordMicrophonePermissionUi.shouldRenderBlockedPanel(
              ui: ctx.ui,
              micPhase: _mic,
              userDeniedThisSession: _micPermissionUserDenied,
            )
            ? Padding(
                key: const ValueKey(
                  'microphone_recovery_visible',
                ),
                padding: const EdgeInsets.only(bottom: 16),
                child: KeyedSubtree(
                  key: _permissionPanelKey,
                  child: MicrophonePermissionBlockedPanel(
                    showSimulatorHelper:
                        _showMicPermissionSimulatorHelper,
                    onOpenSettings: _openMicSettings,
                    onTypeInstead: _typeInsteadFromPermission,
                  ),
                ),
              )
            : const SizedBox.shrink(
                key: ValueKey('microphone_recovery_hidden'),
              ),
      );
  }
}
