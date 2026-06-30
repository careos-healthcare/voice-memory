import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/confirmed_repeat_why_matters_copy.dart';
import '../../features/early_archive/confirmed_repeat_why_matters_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Short, dismissible explanation below confirmed-repeat proof — no primary CTA.
class ConfirmedRepeatWhyMattersCard extends StatefulWidget {
  const ConfirmedRepeatWhyMattersCard({
    super.key,
    this.store,
    this.onDismissed,
    this.skipPrefsLoad = false,
    this.initialDismissed = false,
  });

  const ConfirmedRepeatWhyMattersCard.test({
    super.key,
    this.store,
    this.onDismissed,
    bool dismissed = false,
  })  : skipPrefsLoad = true,
        initialDismissed = dismissed;

  final ConfirmedRepeatWhyMattersStore? store;
  final VoidCallback? onDismissed;
  final bool skipPrefsLoad;
  final bool initialDismissed;

  @override
  State<ConfirmedRepeatWhyMattersCard> createState() =>
      _ConfirmedRepeatWhyMattersCardState();
}

class _ConfirmedRepeatWhyMattersCardState
    extends State<ConfirmedRepeatWhyMattersCard> {
  ConfirmedRepeatWhyMattersStore? _store;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _dismissed = widget.initialDismissed;
      return;
    }
    _dismissed = ConfirmedRepeatWhyMattersStore.cachedDismissed;
    _load();
  }

  Future<void> _load() async {
    await ConfirmedRepeatWhyMattersStore.ensureLoaded();
    if (!mounted) return;
    setState(() => _dismissed = ConfirmedRepeatWhyMattersStore.cachedDismissed);
  }

  Future<void> _hide() async {
    _store ??= widget.store ?? ConfirmedRepeatWhyMattersStore.instance();
    setState(() => _dismissed = true);
    await _store!.dismiss();
    if (!mounted) return;
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink(
        key: Key('confirmed_repeat_why_matters_card_hidden'),
      );
    }

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('confirmed_repeat_why_matters_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConfirmedRepeatWhyMattersCopy.title,
            key: const Key('confirmed_repeat_why_matters_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ConfirmedRepeatWhyMattersCopy.body,
            key: const Key('confirmed_repeat_why_matters_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('confirmed_repeat_why_matters_hide_cta'),
              onPressed: _hide,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(ConfirmedRepeatWhyMattersCopy.hideCta),
            ),
          ),
        ],
      ),
    );
  }
}
