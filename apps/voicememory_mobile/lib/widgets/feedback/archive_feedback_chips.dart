import 'package:flutter/material.dart';

import '../../features/feedback/archive_feedback_coordinator.dart';
import '../../features/feedback/archive_feedback_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// One quiet row of feedback chips under a major result.
///
/// "ArchiveMe gets sharper when you correct it." Tapping a chip saves the
/// feedback locally and swaps the row for a short "Got it." — there is never
/// more than one of these per result screen.
class ArchiveFeedbackChips extends StatefulWidget {
  const ArchiveFeedbackChips({
    super.key,
    required this.targetType,
    this.targetId,
    this.patternTitle,
    this.resultHint,
    this.languageCode,
    this.onSubmit,
  });

  final ArchiveFeedbackTargetType targetType;
  final String? targetId;
  final String? patternTitle;
  final String? resultHint;
  final String? languageCode;

  /// Persists the chosen feedback. Defaults to the local store; injectable so
  /// widget tests never touch storage.
  final Future<void> Function(ArchiveFeedback feedback)? onSubmit;

  @override
  State<ArchiveFeedbackChips> createState() => _ArchiveFeedbackChipsState();
}

class _ArchiveFeedbackChipsState extends State<ArchiveFeedbackChips> {
  bool _submitted = false;

  static const _options = <ArchiveFeedbackType, String>{
    ArchiveFeedbackType.useful: 'Useful',
    ArchiveFeedbackType.tooGeneric: 'Too generic',
    ArchiveFeedbackType.notMe: 'Not me',
    ArchiveFeedbackType.alreadyKnew: 'Already knew',
    ArchiveFeedbackType.moreSpecific: 'More specific',
  };

  @override
  void initState() {
    super.initState();
    ArchiveFeedbackCoordinator.trackFeedbackShown();
  }

  Future<void> _select(ArchiveFeedbackType type) async {
    if (_submitted) return;
    setState(() => _submitted = true);
    final feedback = ArchiveFeedback(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      targetType: widget.targetType,
      createdAt: DateTime.now(),
      targetId: widget.targetId,
      patternTitle: widget.patternTitle,
      resultHint: widget.resultHint,
      languageCode: widget.languageCode,
    );
    final submit = widget.onSubmit ?? _defaultSubmit;
    await submit(feedback);
  }

  Future<void> _defaultSubmit(ArchiveFeedback feedback) async {
    await ArchiveFeedbackCoordinator.saveFeedback(
      type: feedback.type,
      targetType: feedback.targetType,
      targetId: feedback.targetId,
      patternTitle: feedback.patternTitle,
      resultHint: feedback.resultHint,
      languageCode: feedback.languageCode,
      id: feedback.id,
      createdAt: feedback.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 16),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Got it.',
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.success,
              ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Was this useful?',
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _options.entries)
              ActionChip(
                label: Text(entry.value),
                onPressed: () => _select(entry.key),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFF5E6D3)),
                labelStyle: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: 13),
              ),
          ],
        ),
      ],
    );
  }
}
