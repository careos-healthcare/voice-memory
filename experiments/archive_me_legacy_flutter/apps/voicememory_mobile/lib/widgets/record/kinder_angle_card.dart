import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/language/localized_copy.dart';
import '../../features/perspective/kinder_angle_engine.dart';
import '../../features/perspective/kinder_angle_model.dart';
import '../../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Shows a grounded, kinder way to read the same hard moment.
///
/// "Use this check" locks in tomorrow's check with the angle's next check.
/// "Show another angle" steps back to the broader hard-moment read. Set
/// [compact] for the Patterns surface and [fromPatterns] so the right counters
/// fire. [trigger] forces a specific angle (used on the Patterns surface where
/// there is no reflection text).
class KinderAngleCard extends StatefulWidget {
  const KinderAngleCard({
    super.key,
    required this.reflectionText,
    this.patternTitle = '',
    this.specificPrompt = '',
    this.resultHint,
    this.languageCode = 'en',
    this.compact = false,
    this.fromPatterns = false,
    this.trigger,
    this.onCreateCheckIn,
  });

  final String reflectionText;
  final String patternTitle;
  final String specificPrompt;
  final String? resultHint;
  final String languageCode;

  /// Compact layout for the Patterns tab.
  final bool compact;

  /// Routes tracking to the Patterns-specific counters.
  final bool fromPatterns;

  /// Forces a specific angle instead of detecting one from the text.
  final KinderAngleTrigger? trigger;

  /// Creates tomorrow's check-in for [question]. Defaults to the coordinator;
  /// injectable so widget tests never touch storage.
  final Future<void> Function(String question)? onCreateCheckIn;

  @override
  State<KinderAngleCard> createState() => _KinderAngleCardState();
}

class _KinderAngleCardState extends State<KinderAngleCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  bool _broaderAngle = false;
  bool _busy = false;
  bool _done = false;

  String _t(String key) => localized(key, widget.languageCode);

  KinderAngle get _angle => buildKinderAngle(
    reflectionText: widget.reflectionText,
    patternTitle: widget.patternTitle,
    resultHint: widget.resultHint,
    languageCode: widget.languageCode,
    triggerOverride: _broaderAngle
        ? KinderAngleTrigger.genericHardMoment
        : widget.trigger,
  );

  @override
  void initState() {
    super.initState();
    if (widget.fromPatterns) {
      ActivationTracker.trackKinderAngleShownFromPatterns();
    } else {
      ActivationTracker.trackKinderAngleShown();
    }
  }

  void _onShowAnother() {
    if (_busy || _done) return;
    ActivationTracker.trackKinderAngleChanged();
    setState(() => _broaderAngle = true);
  }

  Future<void> _onUseThis() async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    if (widget.fromPatterns) {
      ActivationTracker.trackKinderAngleUsedFromPatterns();
    } else {
      ActivationTracker.trackKinderAngleUsed();
    }
    final create = widget.onCreateCheckIn ?? _defaultCreate;
    await create(_angle.nextCheck);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
  }

  Future<void> _defaultCreate(String question) async {
    await TomorrowCheckInCoordinator.createForTomorrow(
      patternTitle: widget.patternTitle,
      specificPrompt: widget.specificPrompt,
      checkInQuestion: question,
    );
  }

  @override
  Widget build(BuildContext context) {
    final angle = _angle;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.compact
            ? _compactChildren(angle)
            : _fullChildren(angle),
      ),
    );
  }

  List<Widget> _fullChildren(KinderAngle angle) {
    return [
      Text(
        _t('aKinderAngle'),
        style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 17),
      ),
      if (angle.isEarlyRead) ...[
        const SizedBox(height: AppSpacing.xs),
        _earlyReadLabel(),
      ],
      const SizedBox(height: AppSpacing.sm),
      Text(
        angle.kinderRead,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 16, height: 1.45),
      ),
      const SizedBox(height: AppSpacing.md),
      _labelledLine(_t('whyThisHelps'), angle.whyThisHelps),
      const SizedBox(height: AppSpacing.sm),
      _labelledLine(_t('nextCheck'), angle.nextCheck, emphasizeBody: true),
      const SizedBox(height: AppSpacing.sm),
      Text(
        angle.cautionLine,
        style: VoiceMemoryTypography.metadataStyle(
          color: AppColors.textSecondary,
        ).copyWith(fontStyle: FontStyle.italic, height: 1.4),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_done) _confirmation() else ..._actions(),
    ];
  }

  List<Widget> _compactChildren(KinderAngle angle) {
    return [
      Text(
        _t('aKinderAngle'),
        style: VoiceMemoryTypography.metadataStyle(
          color: AppColors.textSecondary,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        angle.kinderRead,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 15, height: 1.4),
      ),
      const SizedBox(height: AppSpacing.sm),
      _labelledLine(_t('nextCheck'), angle.nextCheck, emphasizeBody: true),
      const SizedBox(height: AppSpacing.md),
      if (_done) _confirmation() else ..._actions(),
    ];
  }

  List<Widget> _actions() {
    return [
      SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: _busy ? null : _onUseThis,
          child: Text(_t('useThisCheck')),
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: (_busy || _broaderAngle) ? null : _onShowAnother,
          child: Text(_t('showAnotherAngle')),
        ),
      ),
    ];
  }

  Widget _earlyReadLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _t('earlyRead'),
        style: VoiceMemoryTypography.metadataStyle(
          color: AppColors.accentPrimary,
        ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _labelledLine(
    String label,
    String body, {
    bool emphasizeBody = false,
  }) {
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
                fontSize: emphasizeBody ? 15 : 14,
                fontWeight: emphasizeBody ? FontWeight.w600 : FontWeight.w400,
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
            _t('tomorrowCheckSet'),
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.success,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
