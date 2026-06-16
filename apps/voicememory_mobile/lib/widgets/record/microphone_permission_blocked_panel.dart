import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/voice_capture/microphone_permission_copy.dart';
import '../../features/voice_capture/microphone_permission_state.dart';
import '../../services/capture_pipeline_service.dart';

/// Denied-microphone recovery UI on the Record screen.
class MicrophonePermissionBlockedPanel extends StatelessWidget {
  const MicrophonePermissionBlockedPanel({
    super.key,
    required this.state,
    required this.onAllowMicrophone,
    required this.onOpenSettings,
    required this.onTypeInstead,
  });

  final MicrophonePermissionState state;
  final VoidCallback onAllowMicrophone;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onTypeInstead;

  bool get _showOpenSettings =>
      state == MicrophonePermissionState.deniedOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('microphone_permission_blocked_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          MicrophonePermissionCopy.deniedTitle,
          key: const Key('microphone_permission_denied_title'),
          style: ArchiveMobileTypography.responsiveSectionTitle(context),
        ),
        const SizedBox(height: 8),
        Text(
          MicrophonePermissionCopy.deniedBody,
          key: const Key('microphone_permission_denied_body'),
          style: ArchiveMobileTypography.responsiveBody(context).copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        if (_showOpenSettings)
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              key: const Key('microphone_permission_open_settings'),
              onPressed: onOpenSettings,
              child: const Text(MicrophonePermissionCopy.openSettingsCta),
            ),
          )
        else
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              key: const Key('microphone_permission_allow'),
              onPressed: onAllowMicrophone,
              child: const Text(MicrophonePermissionCopy.allowMicrophoneCta),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            key: const Key('microphone_permission_type_instead'),
            onPressed: () => unawaited(onTypeInstead()),
            child: const Text(MicrophonePermissionCopy.typeInsteadCta),
          ),
        ),
      ],
    );
  }
}

Future<void> navigateToTypeInsteadCapture(
  BuildContext context, {
  String? prompt,
  Future<void> Function(CapturePipelineResult result)? onSaved,
}) async {
  final CapturePipelineResult? result;
  final trimmed = prompt?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    result = await context.push<CapturePipelineResult>(
      '/quick-capture',
      extra: trimmed,
    );
  } else {
    result = await context.push<CapturePipelineResult>('/quick-capture');
  }
  if (result == null || !context.mounted) return;
  if (onSaved != null) {
    await onSaved(result);
  }
}

Future<void> openMicrophoneSettings() => openAppSettings();
