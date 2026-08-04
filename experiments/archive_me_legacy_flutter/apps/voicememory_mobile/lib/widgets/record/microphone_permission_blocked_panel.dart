import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/voice_capture/microphone_permission_copy.dart';
import '../../services/capture_pipeline_service.dart';
import '../../theme/app_colors.dart';

/// Inline recovery UI that replaces recording controls when mic access is
/// denied. The primary action always routes to the operating-system settings.
class MicAccessRecoveryCard extends StatelessWidget {
  const MicAccessRecoveryCard({
    super.key,
    required this.onOpenSettings,
    required this.onTypeInstead,
    this.showSimulatorHelper = false,
  });

  final VoidCallback onOpenSettings;
  final Future<void> Function() onTypeInstead;
  final bool showSimulatorHelper;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('microphone_permission_blocked_panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: _MutedMicrophoneShieldIcon(),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            _openSettingsButton(outlined: false),
            const SizedBox(height: 8),
            const _MicrophonePrivacyDetails(),
            const SizedBox(height: 8),
            Text(
              MicrophonePermissionCopy.typeInsteadBlockedHelper,
              key: const Key('microphone_permission_type_instead_helper'),
              style: ArchiveMobileTypography.responsiveBody(context).copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            _typeInsteadButton(filled: false),
          ],
        ),
      ),
    );
  }

  Widget _openSettingsButton({required bool outlined}) {
    final child = const Text(MicrophonePermissionCopy.openSettingsCta);
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
    final child = const Text(MicrophonePermissionCopy.typeInsteadCta);
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

class _MutedMicrophoneShieldIcon extends StatelessWidget {
  const _MutedMicrophoneShieldIcon();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Microphone access needed',
      child: SizedBox(
        key: const Key('microphone_recovery_shield_icon'),
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.mic_off_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicrophonePrivacyDetails extends StatelessWidget {
  const _MicrophonePrivacyDetails();

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: const Key('microphone_recovery_why_expansion'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text(MicrophonePermissionCopy.whyMicrophoneTitle),
      children: const [
        _PrivacyBullet(text: MicrophonePermissionCopy.localWhisperDetail),
        SizedBox(height: 8),
        _PrivacyBullet(text: MicrophonePermissionCopy.privacyDetail),
      ],
    );
  }
}

class _PrivacyBullet extends StatelessWidget {
  const _PrivacyBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: ArchiveMobileTypography.responsiveBody(context).copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Backward-compatible name used by older capture surfaces.
class MicrophonePermissionBlockedPanel extends MicAccessRecoveryCard {
  const MicrophonePermissionBlockedPanel({
    super.key,
    required super.onOpenSettings,
    required super.onTypeInstead,
    super.showSimulatorHelper,
  });
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
