import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/repeat_return_check/pattern_changed_analytics.dart';
import '../../features/repeat_return_check/pattern_changed_copy.dart';
import '../../features/repeat_return_check/pattern_changed_engine.dart';
import '../../features/repeat_return_check/pattern_changed_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../proof/proof_surface_why_appeared_disclosure.dart';
import '../../features/archive_proof/proof_surface_why_appeared_copy.dart';

/// Major payoff when a repeat meaningfully changes — evidence, not advice.
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
  }) : skipPrefsLoad = true,
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

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textSecondary);
    final phraseStyle = bodyStyle.copyWith(color: AppColors.textPrimary);

    return Container(
      key: const Key('pattern_changed_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF5FAF6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('pattern_changed_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (widget.result.usesPhraseEvidence) ...[
            Text(
              PatternChangedCopy.earlierLabel,
              key: const Key('pattern_changed_earlier_label'),
              style: labelStyle,
            ),
            if (widget.result.earlierPhrase != null)
              Text(
                '"${widget.result.earlierPhrase!}"',
                key: const Key('pattern_changed_earlier_phrase'),
                style: phraseStyle,
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              PatternChangedCopy.thisTimeLabel,
              key: const Key('pattern_changed_this_time_label'),
              style: labelStyle,
            ),
            if (widget.result.thisTimePhrase != null)
              Text(
                '"${widget.result.thisTimePhrase!}"',
                key: const Key('pattern_changed_this_time_phrase'),
                style: phraseStyle,
              ),
          ] else ...[
            Text(
              widget.result.body,
              key: const Key('pattern_changed_body'),
              style: bodyStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.footer,
            key: const Key('pattern_changed_footer'),
            style: bodyStyle.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 2,
                  ),
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
          ProofSurfaceWhyAppearedDisclosure(
            body: ProofSurfaceWhyAppearedCopy.patternChanged,
            surfaceKey: 'pattern_changed',
          ),
        ],
      ),
    );
  }
}
