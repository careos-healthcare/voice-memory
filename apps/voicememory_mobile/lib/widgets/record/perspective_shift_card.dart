import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/language/localized_copy.dart';
import '../../features/perspective/perspective_shift_engine.dart';
import '../../features/perspective/perspective_shift_model.dart';
import '../../features/tomorrow_return/tomorrow_check_in_coordinator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Shows the moment from another useful angle after a result closes.
///
/// "Show another perspective" cycles through [PerspectiveShiftType]s; "Use this
/// check" locks in tomorrow's check with the angle's next check. Set [compact]
/// for the Patterns surface and [fromPatterns] so the right counters fire.
class PerspectiveShiftCard extends StatefulWidget {
  const PerspectiveShiftCard({
    super.key,
    required this.reflectionText,
    this.resultHint,
    this.checkInQuestion,
    this.patternTitle = '',
    this.specificPrompt = '',
    this.languageCode = 'en',
    this.compact = false,
    this.fromPatterns = false,
    this.onCreateCheckIn,
  });

  final String reflectionText;
  final String? resultHint;
  final String? checkInQuestion;
  final String patternTitle;
  final String specificPrompt;
  final String languageCode;

  /// Compact layout for the Patterns tab.
  final bool compact;

  /// Routes tracking to the Patterns-specific counters.
  final bool fromPatterns;

  /// Creates tomorrow's check-in for [question]. Defaults to the coordinator;
  /// injectable so widget tests never touch storage.
  final Future<void> Function(String question)? onCreateCheckIn;

  @override
  State<PerspectiveShiftCard> createState() => _PerspectiveShiftCardState();
}

class _PerspectiveShiftCardState extends State<PerspectiveShiftCard> {
  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  late final List<PerspectiveShiftType> _cycle =
      perspectiveCycle(widget.resultHint);
  int _index = 0;
  bool _busy = false;
  bool _done = false;

  String _t(String key) => localized(key, widget.languageCode);

  PerspectiveShift get _shift => buildPerspectiveShift(
        reflectionText: widget.reflectionText,
        resultHint: widget.resultHint,
        checkInQuestion: widget.checkInQuestion,
        patternTitle: widget.patternTitle,
        preferredType: _cycle[_index % _cycle.length],
      );

  @override
  void initState() {
    super.initState();
    if (widget.fromPatterns) {
      ActivationTracker.trackPerspectiveShiftShownFromPatterns();
    } else {
      ActivationTracker.trackPerspectiveShiftShown();
    }
  }

  void _onShowAnother() {
    if (_busy || _done) return;
    ActivationTracker.trackPerspectiveShiftChanged();
    setState(() => _index = (_index + 1) % _cycle.length);
  }

  Future<void> _onUseThis() async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    if (widget.fromPatterns) {
      ActivationTracker.trackPerspectiveShiftUsedFromPatterns();
    } else {
      ActivationTracker.trackPerspectiveShiftUsed();
    }
    final create = widget.onCreateCheckIn ?? _defaultCreate;
    await create(_shift.nextCheck);
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
    final shift = _shift;
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
        children: widget.compact ? _compactChildren(shift) : _fullChildren(shift),
      ),
    );
  }

  List<Widget> _fullChildren(PerspectiveShift shift) {
    return [
      Text(
        _t('anotherPerspective'),
        style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 17),
      ),
      if (shift.isEarlyRead) ...[
        const SizedBox(height: AppSpacing.xs),
        _earlyReadLabel(shift),
      ],
      const SizedBox(height: AppSpacing.sm),
      Text(
        shift.title,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        shift.perspective,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 15, height: 1.45),
      ),
      const SizedBox(height: AppSpacing.md),
      _labelledLine(_t('whyUseful'), shift.whyUseful),
      const SizedBox(height: AppSpacing.sm),
      _labelledLine(_t('nextCheck'), shift.nextCheck, emphasizeBody: true),
      const SizedBox(height: AppSpacing.md),
      if (_done)
        _confirmation()
      else ...[
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
            onPressed: _busy ? null : _onShowAnother,
            child: Text(_t('showAnotherPerspective')),
          ),
        ),
      ],
    ];
  }

  List<Widget> _compactChildren(PerspectiveShift shift) {
    return [
      Text(
        _t('anotherPerspective'),
        style: VoiceMemoryTypography.metadataStyle(
          color: AppColors.textSecondary,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        shift.perspective,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 15, height: 1.4),
      ),
      const SizedBox(height: AppSpacing.sm),
      _labelledLine(_t('nextCheck'), shift.nextCheck, emphasizeBody: true),
      const SizedBox(height: AppSpacing.md),
      if (_done)
        _confirmation()
      else ...[
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
            onPressed: _busy ? null : _onShowAnother,
            child: Text(_t('showAnother')),
          ),
        ),
      ],
    ];
  }

  Widget _earlyReadLabel(PerspectiveShift shift) {
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

  Widget _labelledLine(String label, String body, {bool emphasizeBody = false}) {
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
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textPrimary,
          ).copyWith(
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
