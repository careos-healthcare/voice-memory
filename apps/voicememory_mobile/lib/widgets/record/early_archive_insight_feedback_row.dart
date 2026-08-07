import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/early_archive_insight_feedback_analytics.dart';
import '../../features/early_archive/early_archive_insight_feedback_copy.dart';
import '../../features/early_archive/early_archive_insight_feedback_models.dart';
import '../../features/early_archive/early_archive_insight_feedback_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Compact accuracy feedback under early archive proof cards and timelines.
class EarlyArchiveInsightFeedbackRow extends StatefulWidget {
  const EarlyArchiveInsightFeedbackRow({
    super.key,
    required this.insightType,
    required this.surface,
    required this.entryCount,
  });

  final EarlyArchiveInsightType insightType;
  final String surface;
  final int entryCount;

  @override
  State<EarlyArchiveInsightFeedbackRow> createState() =>
      _EarlyArchiveInsightFeedbackRowState();
}

class _EarlyArchiveInsightFeedbackRowState
    extends State<EarlyArchiveInsightFeedbackRow> {
  EarlyArchiveInsightFeedbackValue? _savedValue;

  String get _storageKey =>
      '${widget.insightType.name}|${widget.surface}|${widget.entryCount}';

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
      insightType: widget.insightType,
      value: value,
      entryCount: widget.entryCount,
      surface: widget.surface,
    );
    if (!mounted) return;
    setState(() => _savedValue = value);

    final record = EarlyArchiveInsightFeedbackRecord(
      insightType: widget.insightType,
      value: value,
      entryCount: widget.entryCount,
      surface: widget.surface,
      createdAt: DateTime.now(),
    );
    try {
      await EarlyArchiveInsightFeedbackStore.instance().save(record);
    } catch (_) {
      // Local persistence is best-effort — feedback still registers in analytics.
    }
  }

  String? _acknowledgementFor(EarlyArchiveInsightFeedbackValue value) {
    return switch (value) {
      EarlyArchiveInsightFeedbackValue.wrongPattern =>
        EarlyArchiveInsightFeedbackCopy.wrongPatternAcknowledgement,
      EarlyArchiveInsightFeedbackValue.feelsRight ||
      EarlyArchiveInsightFeedbackValue.notQuite =>
        EarlyArchiveInsightFeedbackCopy.savedAcknowledgement,
    };
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
          _acknowledgementFor(_savedValue!)!,
          key: Key('early_archive_insight_feedback_ack_${_savedValue!.name}'),
          style: helperStyle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        key: Key(
          'early_archive_insight_feedback_row_${widget.insightType.name}',
        ),
        spacing: AppSpacing.xs,
        runSpacing: 2,
        children: [
          TextButton(
            key: const Key('early_archive_insight_feedback_feels_right'),
            onPressed: () => _save(EarlyArchiveInsightFeedbackValue.feelsRight),
            style: buttonStyle,
            child: Text(
              EarlyArchiveInsightFeedbackCopy.feelsRight,
              style: helperStyle.copyWith(color: AppColors.accentPrimary),
            ),
          ),
          TextButton(
            key: const Key('early_archive_insight_feedback_not_quite'),
            onPressed: () => _save(EarlyArchiveInsightFeedbackValue.notQuite),
            style: buttonStyle,
            child: Text(
              EarlyArchiveInsightFeedbackCopy.notQuite,
              style: helperStyle,
            ),
          ),
          TextButton(
            key: const Key('early_archive_insight_feedback_wrong_pattern'),
            onPressed: () =>
                _save(EarlyArchiveInsightFeedbackValue.wrongPattern),
            style: buttonStyle,
            child: Text(
              EarlyArchiveInsightFeedbackCopy.wrongPattern,
              style: helperStyle,
            ),
          ),
        ],
      ),
    );
  }
}
