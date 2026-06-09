import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/empty_archive_experience.dart';
import '../product/consumer_ui_copy.dart';

/// Primary voice capture + secondary typed capture — same labels everywhere.
class CaptureEntryActions extends StatelessWidget {
  const CaptureEntryActions({
    super.key,
    required this.onRecord,
    this.onGradient = false,
    this.typeCapturePrompt,
    this.recordButtonLabel,
    this.onLogPressureMoment,
  });

  final VoidCallback onRecord;
  final bool onGradient;
  final String? recordButtonLabel;

  /// Prefills quick text capture when user chose a Start Here prompt first.
  final String? typeCapturePrompt;

  /// When set, surfaces a low-friction "Log pressure moment" entry point.
  final VoidCallback? onLogPressureMoment;

  static const logPressureMomentLabel = 'Log pressure moment';

  void _typeInstead(BuildContext context) {
    final prompt = typeCapturePrompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      context.push('/quick-capture', extra: prompt);
      return;
    }
    context.push('/quick-capture');
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
            onPressed: () => _typeInstead(context),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onRecord,
            icon: const Icon(Icons.mic),
            label: Text(recordButtonLabel ?? ConsumerUiCopy.startRecording),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _typeInstead(context),
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
