import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../design/empty_archive_experience.dart';
import '../features/voice_capture/microphone_permission_copy.dart';
import '../product/consumer_ui_copy.dart';
import '../record/record_screen_framing_copy.dart';
import '../router/route_catalog.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/capture_pipeline_service.dart';
import '../theme/app_spacing.dart';
import '../theme/archive_semantic_colors.dart';

/// Primary voice capture + secondary typed capture — same labels everywhere.
enum CapturePressureMomentPresentation { button, textLink, none }

class CaptureEntryActions extends StatelessWidget {
  const CaptureEntryActions({
    super.key,
    required this.onRecord,
    this.onGradient = false,
    this.typeCapturePrompt,
    this.recordButtonLabel,
    this.recordButtonKey,
    this.onLogPressureMoment,
    this.onTextThoughtSaved,
    this.underRecordHelper,
    this.pressureMomentPresentation = CapturePressureMomentPresentation.button,
    this.onHowItWorks,
    this.preferTypedFirst = false,
    this.minimalFirstRun = false,
  });

  final VoidCallback onRecord;
  final bool onGradient;
  final String? recordButtonLabel;
  final Key? recordButtonKey;

  /// When true, typed capture is primary before voice (capture friction fix).
  final bool preferTypedFirst;

  /// Tiny confidence helper rendered directly under the record CTA — only
  /// passed before the first save. Plain text, never a new choice.
  final String? underRecordHelper;

  /// Passes a prompt hint into quick text capture when user chose one first.
  final String? typeCapturePrompt;

  /// When set, surfaces a low-friction "Log pressure moment" entry point.
  final VoidCallback? onLogPressureMoment;

  /// Called after a typed thought saves successfully (Record post-save flow).
  final Future<void> Function(CapturePipelineResult result)? onTextThoughtSaved;

  final CapturePressureMomentPresentation pressureMomentPresentation;
  final VoidCallback? onHowItWorks;
  final bool minimalFirstRun;

  static const logPressureMomentLabel = 'Log pressure moment';

  Future<void> _typeInstead(BuildContext context) async {
    final CapturePipelineResult? result;
    if (minimalFirstRun) {
      result = await context.push<CapturePipelineResult>('/quick-capture');
    } else {
      final prompt = typeCapturePrompt?.trim();
      if (prompt != null && prompt.isNotEmpty) {
        result = await context.push<CapturePipelineResult>(
          '/quick-capture',
          extra: prompt,
        );
      } else {
        result = await context.push<CapturePipelineResult>('/quick-capture');
      }
    }
    if (result == null || !context.mounted) return;
    if (onTextThoughtSaved != null) {
      await onTextThoughtSaved!(result);
      return;
    }
    context.go(RouteCatalog.recordHome, extra: result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ArchiveSemanticColors.of(context);
    if (onGradient) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: onRecord,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              minimumSize: const Size(48, 48),
            ),
            child: Text(recordButtonLabel ?? ConsumerUiCopy.startRecording),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => unawaited(_typeInstead(context)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.92),
              minimumSize: const Size(48, 44),
            ),
            child: const Text(EmptyArchiveCopy.typeInsteadCta),
          ),
          if (onLogPressureMoment != null &&
              pressureMomentPresentation ==
                  CapturePressureMomentPresentation.button)
            TextButton(
              onPressed: onLogPressureMoment,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.92),
                minimumSize: const Size(48, 44),
              ),
              child: const Text(logPressureMomentLabel),
            ),
        ],
      );
    }

    final helper = underRecordHelper;
    if (helper != null) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.firstSaveConfidenceSeen,
        entryCount: 0,
        oncePerSession: true,
      );
    }

    if (minimalFirstRun) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              key: recordButtonKey,
              onPressed: onRecord,
              child: Text(
                recordButtonLabel ??
                    MicrophonePermissionCopy.requestMicrophoneCta,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('capture_entry_type_instead_cta'),
              onPressed: () => unawaited(_typeInstead(context)),
              child: const Text(EmptyArchiveCopy.typeInsteadCta),
            ),
          ),
        ],
      );
    }

    if (preferTypedFirst) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('capture_entry_type_first_cta'),
              onPressed: () => unawaited(_typeInstead(context)),
              icon: const Icon(Icons.keyboard_outlined),
              label: Text(EmptyArchiveCopy.typeInsteadCta),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              key: recordButtonKey,
              onPressed: onRecord,
              icon: const Icon(Icons.mic),
              label: Text(recordButtonLabel ?? ConsumerUiCopy.startRecording),
            ),
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                helper,
                key: const Key('first_save_one_sentence_helper'),
                textAlign: TextAlign.center,
                style: ArchiveMobileTypography.responsiveHelper(
                  context,
                ).copyWith(color: colors.secondaryText),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton.icon(
            key: recordButtonKey,
            onPressed: onRecord,
            icon: const Icon(Icons.mic),
            label: Text(recordButtonLabel ?? ConsumerUiCopy.startRecording),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              helper,
              key: const Key('first_save_one_sentence_helper'),
              textAlign: TextAlign.center,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: colors.secondaryText),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => unawaited(_typeInstead(context)),
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text(EmptyArchiveCopy.typeInsteadCta),
          ),
        ),
        if (onHowItWorks != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              key: const Key('capture_how_it_works_link'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: colors.secondaryText,
              ),
              onPressed: onHowItWorks,
              child: Text(
                RecordScreenFramingCopy.firstRunPrivacyLink,
                style: const TextStyle(
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
        if (onLogPressureMoment != null &&
            pressureMomentPresentation ==
                CapturePressureMomentPresentation.textLink) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('capture_pressure_moment_link'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: colors.secondaryText,
              ),
              onPressed: onLogPressureMoment,
              child: Text(
                RecordScreenFramingCopy.firstUsePressureMomentLink,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
        if (onLogPressureMoment != null &&
            pressureMomentPresentation ==
                CapturePressureMomentPresentation.button) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogPressureMoment,
              icon: const Icon(Icons.bolt_outlined),
              label: const Text(logPressureMomentLabel),
            ),
          ),
        ],
      ],
    );
  }
}
