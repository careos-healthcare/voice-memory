import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_copy.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Lightweight beta-only mission card — informational, never blocks recording.
class ArchiveBetaMissionCard extends StatefulWidget {
  const ArchiveBetaMissionCard({
    required this.showStartCta, super.key,
    this.onStart,
    this.onDismissed,
    this.store,
    this.skipPrefsLoad = false,
    this.initialDismissed = false,
  });

  const ArchiveBetaMissionCard.test({
    required this.showStartCta, super.key,
    this.onStart,
    this.onDismissed,
    this.store,
    bool dismissed = false,
  }) : skipPrefsLoad = true,
       initialDismissed = dismissed;

  final bool showStartCta;
  final VoidCallback? onStart;
  final VoidCallback? onDismissed;
  final ArchiveBetaMissionStore? store;
  final bool skipPrefsLoad;
  final bool initialDismissed;

  @override
  State<ArchiveBetaMissionCard> createState() => _ArchiveBetaMissionCardState();
}

class _ArchiveBetaMissionCardState extends State<ArchiveBetaMissionCard> {
  ArchiveBetaMissionStore? _store;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _dismissed = widget.initialDismissed;
      return;
    }
    _dismissed = ArchiveBetaMissionStore.cachedDismissed;
    unawaited(_load());
  }

  Future<void> _load() async {
    await ArchiveBetaMissionStore.ensureLoaded();
    if (!mounted) return;
    setState(() => _dismissed = ArchiveBetaMissionStore.cachedDismissed);
  }

  Future<void> _hide() async {
    _store ??= widget.store ?? ArchiveBetaMissionStore.instance();
    setState(() => _dismissed = true);
    await _store!.dismiss();
    if (!mounted) return;
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink(
        key: Key('archive_beta_mission_card_hidden'),
      );
    }

    final bodyStyle = ArchiveMobileTypography.listSubtitle(context);
    final stepStyle = bodyStyle.copyWith(height: 1.45);

    return Container(
      key: const Key('archive_beta_mission_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveBetaMissionCopy.title,
            key: const Key('archive_beta_mission_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveBetaMissionCopy.mission,
            key: const Key('archive_beta_mission_mission'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < ArchiveBetaMissionCopy.steps.length; i++) ...[
            Text(
              '${i + 1}. ${ArchiveBetaMissionCopy.steps[i]}',
              key: Key('archive_beta_mission_step_${i + 1}'),
              style: stepStyle,
            ),
            if (i < ArchiveBetaMissionCopy.steps.length - 1)
              const SizedBox(height: 4),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveBetaMissionCopy.feedbackLine,
            key: const Key('archive_beta_mission_feedback_line'),
            style: bodyStyle,
          ),
          if (widget.showStartCta) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('archive_beta_mission_start_cta'),
                onPressed: widget.onStart,
                child: const Text(ArchiveBetaMissionCopy.startCta),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('archive_beta_mission_hide_cta'),
              onPressed: _hide,
              child: const Text(ArchiveBetaMissionCopy.hideCta),
            ),
          ),
        ],
      ),
    );
  }
}