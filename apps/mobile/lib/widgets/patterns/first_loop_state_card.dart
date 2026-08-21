import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Which step of the compressed first loop the Patterns tab should nudge.
enum FirstLoopStatePhase { recordMoment, chooseCheck, ready }

/// Keeps the Patterns tab simple before the first loop is ready: it points at
/// the single next step instead of a full dashboard.
class FirstLoopStateCard extends StatelessWidget {
  const FirstLoopStateCard({
    required this.phase, required this.onRecord, super.key,
    this.question,
  });

  final FirstLoopStatePhase phase;
  final VoidCallback onRecord;
  final String? question;

  static const Color _surface = Color(0xFFFFFBF5);
  static const Color _border = AppColors.warmBorder;

  String get _title {
    switch (phase) {
      case FirstLoopStatePhase.recordMoment:
        return 'Record one moment';
      case FirstLoopStatePhase.chooseCheck:
        return 'Choose tomorrow\u2019s check';
      case FirstLoopStatePhase.ready:
        return 'Tomorrow\u2019s check is ready';
    }
  }

  String get _body {
    switch (phase) {
      case FirstLoopStatePhase.recordMoment:
        return ConsumerUiCopy.patternsEarlyStateBody;
      case FirstLoopStatePhase.chooseCheck:
        return 'Pick one thing to check tomorrow so this moment can become a '
            'pattern.';
      case FirstLoopStatePhase.ready:
        return 'Come back tomorrow and check this.';
    }
  }

  String get _cta {
    switch (phase) {
      case FirstLoopStatePhase.recordMoment:
        return 'Record one moment';
      case FirstLoopStatePhase.chooseCheck:
        return 'Choose tomorrow\u2019s check';
      case FirstLoopStatePhase.ready:
        return 'Record another moment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showQuestion =
        phase == FirstLoopStatePhase.ready &&
        question != null &&
        question!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45, fontSize: 14),
          ),
          if (showQuestion) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              question!,
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(onPressed: onRecord, child: Text(_cta)),
          ),
          if (phase == FirstLoopStatePhase.ready) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                'Come back tomorrow',
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}