import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/pressure_retention/start_here_save_receipt_model.dart';
import '../services/capture_pipeline_service.dart';
import '../design/empty_archive_experience.dart';
import '../product/consumer_ui_copy.dart';
import '../services/activation_funnel_analytics.dart';
import '../theme/app_colors.dart';

/// Primary voice capture + secondary typed capture — same labels everywhere.
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
  });

  final VoidCallback onRecord;
  final bool onGradient;
  final String? recordButtonLabel;
  final Key? recordButtonKey;

  /// Tiny confidence helper rendered directly under the record CTA — only
  /// passed before the first save. Plain text, never a new choice.
  final String? underRecordHelper;

  /// Passes a prompt hint into quick text capture when user chose one first.
  final String? typeCapturePrompt;

  /// When set, surfaces a low-friction "Log pressure moment" entry point.
  final VoidCallback? onLogPressureMoment;

  /// Called after a typed thought saves successfully (Record post-save flow).
  final Future<void> Function(CapturePipelineResult result)? onTextThoughtSaved;

  static const logPressureMomentLabel = 'Log pressure moment';

  Future<void> _typeInstead(BuildContext context) async {
    final prompt = typeCapturePrompt?.trim();
    final CapturePipelineResult? result;
    if (prompt != null && prompt.isNotEmpty) {
      result = await context.push<CapturePipelineResult>(
        '/quick-capture',
        extra: prompt,
      );
    } else {
      result = await context.push<CapturePipelineResult>('/quick-capture');
    }
    if (result == null || !context.mounted) return;
    if (onTextThoughtSaved != null) {
      await onTextThoughtSaved!(result);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(StartHereSaveReceipt.defaultTitle)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          if (onLogPressureMoment != null)
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
              ).copyWith(color: AppColors.textSecondary),
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
        if (onLogPressureMoment != null) ...[
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
