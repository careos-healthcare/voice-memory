import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/repeat_return_check/pattern_changed_analytics.dart';
import '../../features/repeat_return_check/pattern_changed_copy.dart';
import '../../features/repeat_return_check/pattern_changed_engine.dart';
import '../../features/repeat_return_check/pattern_changed_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Quiet win when a repeat softens or meaningfully changes — no gamification.
class PatternChangedCard extends StatefulWidget {
  const PatternChangedCard({
    super.key,
    required this.result,
    required this.entryCount,
    required this.surface,
    this.showRecordCta = true,
    this.onRecord,
    this.onDismissed,
    this.store,
    this.skipPrefsLoad = false,
    this.initialDismissed = false,
  });

  const PatternChangedCard.test({
    super.key,
    required this.result,
    required this.entryCount,
    required this.surface,
    this.showRecordCta = true,
    this.onRecord,
    this.onDismissed,
    this.store,
    bool dismissed = false,
  })  : skipPrefsLoad = true,
        initialDismissed = dismissed;

  final PatternChangedResult result;
  final int entryCount;
  final String surface;
  final bool showRecordCta;
  final VoidCallback? onRecord;
  final VoidCallback? onDismissed;
  final PatternChangedStore? store;
  final bool skipPrefsLoad;
  final bool initialDismissed;

  @override
  State<PatternChangedCard> createState() => _PatternChangedCardState();
}

class _PatternChangedCardState extends State<PatternChangedCard> {
  PatternChangedStore? _store;
  bool _dismissed = false;
  bool _seenLogged = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _dismissed = widget.initialDismissed;
      return;
    }
    _dismissed = PatternChangedStore.isDismissed(
      entryId: widget.result.entryId,
      type: widget.result.type,
    );
    _load();
  }

  Future<void> _load() async {
    await PatternChangedStore.ensureLoaded();
    if (!mounted) return;
    setState(
      () => _dismissed = PatternChangedStore.isDismissed(
        entryId: widget.result.entryId,
        type: widget.result.type,
      ),
    );
  }

  Future<void> _dismiss() async {
    _store ??= widget.store ?? PatternChangedStore.instance();
    setState(() => _dismissed = true);
    PatternChangedAnalytics.dismissed(
      surface: widget.surface,
      entryCount: widget.entryCount,
      changeType: widget.result.type,
    );
    await _store!.dismiss(
      entryId: widget.result.entryId,
      type: widget.result.type,
    );
    if (!mounted) return;
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink(key: Key('pattern_changed_card_hidden'));
    }

    if (!_seenLogged) {
      _seenLogged = true;
      PatternChangedAnalytics.seen(
        surface: widget.surface,
        entryCount: widget.entryCount,
        changeType: widget.result.type,
      );
    }

    final background = widget.result.isCelebration
        ? const Color(0xFFF5FAF6)
        : const Color(0xFFFAFAF8);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );

    return Container(
      key: const Key('pattern_changed_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: background),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('pattern_changed_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('pattern_changed_body'),
            style: bodyStyle,
          ),
          if (widget.showRecordCta && widget.onRecord != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('pattern_changed_record_cta'),
                onPressed: widget.onRecord,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(PatternChangedCopy.recordIfReturnsCta),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('pattern_changed_dismiss'),
              onPressed: _dismiss,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(PatternChangedCopy.dismiss),
            ),
          ),
        ],
      ),
    );
  }
}
