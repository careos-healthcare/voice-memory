import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/export/private_recap_engine.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/export/private_recap_actions.dart';

/// Full view of a single saved moment, preserving the original words.
class KeyMomentDetailScreen extends StatefulWidget {
  const KeyMomentDetailScreen({
    super.key,
    required this.moment,
    this.onUseCheck,
  });

  final KeyMoment moment;

  /// Creates tomorrow's check-in for [question]. Defaults to the coordinator;
  /// injectable so widget tests never touch storage.
  final Future<void> Function(String question)? onUseCheck;

  @override
  State<KeyMomentDetailScreen> createState() => _KeyMomentDetailScreenState();
}

class _KeyMomentDetailScreenState extends State<KeyMomentDetailScreen> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  bool _busy = false;
  bool _done = false;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _useCheck() async {
    final nextCheck = widget.moment.nextCheck;
    if (nextCheck == null || _busy || _done) return;
    setState(() => _busy = true);
    ActivationTracker.trackKeyMomentUseCheckTapped();
    final create = widget.onUseCheck ?? _defaultCreate;
    await create(nextCheck);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
  }

  Future<void> _defaultCreate(String question) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: widget.moment.patternTitle ?? '',
      specificPrompt: '',
      checkInQuestion: question,
    );
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final resultLabel = keyMomentResultLabel(moment.resultHint);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Moment'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dateLabel(moment.date),
                style: VoiceMemoryTypography.metadataStyle(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                moment.title,
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: _warmSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _warmBorder),
                ),
                child: Text(
                  moment.originalText,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 16, height: 1.5),
                ),
              ),
              if (moment.patternTitle != null) ...[
                const SizedBox(height: AppSpacing.md),
                _labelledLine('Pattern', moment.patternTitle!),
              ],
              if (resultLabel != null) ...[
                const SizedBox(height: AppSpacing.md),
                _labelledLine('Result', 'This $resultLabel.'),
              ],
              if (moment.nextCheck != null) ...[
                const SizedBox(height: AppSpacing.md),
                _labelledLine('Next check', moment.nextCheck!, emphasize: true),
                const SizedBox(height: AppSpacing.lg),
                if (_done)
                  _confirmation()
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _useCheck,
                      child: const Text('Use this check'),
                    ),
                  ),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => context.go('/record'),
                    child: const Text(ConsumerUiCopy.recordNextMomentCta),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _keepACopy(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keepACopy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keep a private copy',
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrivateRecapActions(
          recap: PrivateRecapEngine.fromKeyMoment(widget.moment),
        ),
      ],
    );
  }

  Widget _labelledLine(String label, String body, {bool emphasize = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: VoiceMemoryTypography.bodyStyle(color: AppColors.textPrimary)
              .copyWith(
                fontSize: emphasize ? 16 : 15,
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                height: 1.4,
              ),
        ),
      ],
    );
  }

  Widget _confirmation() {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Tomorrow\u2019s check is set.',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.success,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
