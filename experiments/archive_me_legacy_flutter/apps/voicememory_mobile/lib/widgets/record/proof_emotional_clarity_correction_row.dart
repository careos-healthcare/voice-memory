import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_improvement/proof_emotional_clarity_copy_fix.dart';
import '../../features/early_archive/early_archive_insight_feedback_analytics.dart';
import '../../features/early_archive/early_archive_insight_feedback_models.dart';
import '../../features/early_archive/early_archive_insight_feedback_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Correction row for proof emotional clarity — reuses early archive feedback store.
class ProofEmotionalClarityCorrectionRow extends StatefulWidget {
  const ProofEmotionalClarityCorrectionRow({
    super.key,
    required this.entryCount,
    this.surface = 'first_proof_payoff',
  });

  final int entryCount;
  final String surface;

  @override
  State<ProofEmotionalClarityCorrectionRow> createState() =>
      _ProofEmotionalClarityCorrectionRowState();
}

class _ProofEmotionalClarityCorrectionRowState
    extends State<ProofEmotionalClarityCorrectionRow> {
  EarlyArchiveInsightFeedbackValue? _savedValue;

  String get _storageKey =>
      '${EarlyArchiveInsightType.confirmedRepeat.name}|${widget.surface}|${widget.entryCount}';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    await EarlyArchiveInsightFeedbackStore.ensureLoaded();
    if (!mounted) return;
    final existing = EarlyArchiveInsightFeedbackStore.latestForKey(
      _storageKey,
    )?.value;
    if (existing != null) {
      setState(() => _savedValue = existing);
    }
  }

  Future<void> _save(EarlyArchiveInsightFeedbackValue value) async {
    EarlyArchiveInsightFeedbackAnalytics.record(
      insightType: EarlyArchiveInsightType.confirmedRepeat,
      value: value,
      entryCount: widget.entryCount,
      surface: widget.surface,
    );
    if (!mounted) return;
    setState(() => _savedValue = value);

    final record = EarlyArchiveInsightFeedbackRecord(
      insightType: EarlyArchiveInsightType.confirmedRepeat,
      value: value,
      entryCount: widget.entryCount,
      surface: widget.surface,
      createdAt: DateTime.now(),
    );
    try {
      await EarlyArchiveInsightFeedbackStore.instance().save(record);
    } catch (_) {
      // Local persistence is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 12, height: 1.35);
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    if (_savedValue != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          'Thanks — saved locally.',
          key: Key(
            'proof_emotional_clarity_correction_ack_${_savedValue!.name}',
          ),
          style: helperStyle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProofEmotionalClarityCopyFix.correctionPrompt,
            key: const Key('proof_emotional_clarity_correction_prompt'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            key: const Key('proof_emotional_clarity_correction_row'),
            spacing: AppSpacing.xs,
            runSpacing: 2,
            children: [
              TextButton(
                key: const Key(
                  'proof_emotional_clarity_correction_feels_right',
                ),
                onPressed: () =>
                    _save(EarlyArchiveInsightFeedbackValue.feelsRight),
                style: buttonStyle,
                child: Text(
                  ProofEmotionalClarityCopyFix.correctionFeelsRight,
                  style: helperStyle.copyWith(color: AppColors.accentPrimary),
                ),
              ),
              TextButton(
                key: const Key('proof_emotional_clarity_correction_not_quite'),
                onPressed: () =>
                    _save(EarlyArchiveInsightFeedbackValue.notQuite),
                style: buttonStyle,
                child: Text(ProofEmotionalClarityCopyFix.correctionNotQuite),
              ),
              TextButton(
                key: const Key('proof_emotional_clarity_correction_it_changed'),
                onPressed: () =>
                    _save(EarlyArchiveInsightFeedbackValue.wrongPattern),
                style: buttonStyle,
                child: Text(ProofEmotionalClarityCopyFix.correctionItChanged),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
