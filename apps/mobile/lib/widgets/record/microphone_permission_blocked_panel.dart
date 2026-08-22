import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

/// Denied-microphone recovery UI on the Record screen.
class MicrophonePermissionBlockedPanel extends StatelessWidget {
  const MicrophonePermissionBlockedPanel({
    required this.onOpenSettings, required this.onTypeInstead, super.key,
    this.showSimulatorHelper = false,
  });

  final VoidCallback onOpenSettings;
  final Future<void> Function() onTypeInstead;
  final bool showSimulatorHelper;

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
        if (showSimulatorHelper) ...[
          const SizedBox(height: 8),
          Text(
            MicrophonePermissionCopy.simulatorHelper,
            key: const Key('microphone_permission_simulator_helper'),
            style: ArchiveMobileTypography.responsiveBody(context).copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          MicrophonePermissionCopy.typeInsteadBlockedHelper,
          key: const Key('microphone_permission_type_instead_helper'),
          style: ArchiveMobileTypography.responsiveBody(context).copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        if (showSimulatorHelper) ...[
          _typeInsteadButton(filled: true),
          const SizedBox(height: 8),
          _openSettingsButton(outlined: true),
        ] else ...[
          _openSettingsButton(outlined: false),
          const SizedBox(height: 8),
          _typeInsteadButton(filled: false),
        ],
      ],
    );
  }

  Widget _openSettingsButton({required bool outlined}) {
    const child = Text(MicrophonePermissionCopy.openSettingsCta);
    if (outlined) {
      return SizedBox(
        height: 48,
        width: double.infinity,
        child: OutlinedButton(
          key: const Key('microphone_permission_open_settings'),
          onPressed: onOpenSettings,
          child: child,
        ),
      );
    }
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        key: const Key('microphone_permission_open_settings'),
        onPressed: onOpenSettings,
        child: child,
      ),
    );
  }

  Widget _typeInsteadButton({required bool filled}) {
    const child = Text(MicrophonePermissionCopy.typeInsteadCta);
    if (filled) {
      return SizedBox(
        height: 48,
        width: double.infinity,
        child: FilledButton(
          key: const Key('microphone_permission_type_instead'),
          onPressed: () => unawaited(onTypeInstead()),
          child: child,
        ),
      );
    }
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        key: const Key('microphone_permission_type_instead'),
        onPressed: () => unawaited(onTypeInstead()),
        child: child,
      ),
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