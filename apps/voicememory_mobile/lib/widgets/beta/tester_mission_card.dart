import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta/tester_mission_analytics.dart';
import '../../features/beta/tester_mission_copy.dart';
import '../../features/beta/tester_mission_model.dart';
import '../../features/beta/tester_mission_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Beta-only guided test mission — informational, never blocks recording.
class TesterMissionCard extends StatefulWidget {
  const TesterMissionCard({
    super.key,
    required this.mission,
    this.onDismissed,
    this.store,
    this.skipPrefsLoad = false,
    this.initialDismissed = false,
  });

  const TesterMissionCard.test({
    super.key,
    required this.mission,
    this.onDismissed,
    this.store,
    bool dismissed = false,
  }) : skipPrefsLoad = true,
       initialDismissed = dismissed;

  final TesterMissionResult mission;
  final VoidCallback? onDismissed;
  final TesterMissionStore? store;
  final bool skipPrefsLoad;
  final bool initialDismissed;

  @override
  State<TesterMissionCard> createState() => _TesterMissionCardState();
}

class _TesterMissionCardState extends State<TesterMissionCard> {
  TesterMissionStore? _store;
  bool _dismissed = false;
  bool _seenLogged = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _dismissed = widget.initialDismissed;
      return;
    }
    _dismissed = TesterMissionStore.isDismissed;
    unawaited(_load());
  }

  Future<void> _load() async {
    await TesterMissionStore.ensureLoaded();
    if (!mounted) return;
    setState(() => _dismissed = TesterMissionStore.isDismissed);
  }

  void _logSeenIfNeeded() {
    if (_seenLogged || _dismissed) return;
    _seenLogged = true;
    TesterMissionAnalytics.seen(
      entryCount: widget.mission.entryCount,
      missionStep: widget.mission.step.analyticsValue,
    );
  }

  Future<void> _hideForSession() async {
    _store ??= widget.store ?? TesterMissionStore.instance();
    setState(() => _dismissed = true);
    _store!.dismissForSession();
    TesterMissionAnalytics.dismissed(
      entryCount: widget.mission.entryCount,
      missionStep: widget.mission.step.analyticsValue,
      reason: 'session',
    );
    if (!mounted) return;
    widget.onDismissed?.call();
  }

  Future<void> _hideForToday() async {
    _store ??= widget.store ?? TesterMissionStore.instance();
    setState(() => _dismissed = true);
    await _store!.dismissForDay();
    TesterMissionAnalytics.dismissed(
      entryCount: widget.mission.entryCount,
      missionStep: widget.mission.step.analyticsValue,
      reason: 'day',
    );
    if (!mounted) return;
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink(key: Key('tester_mission_card_hidden'));
    }

    _logSeenIfNeeded();

    if (widget.mission.presentation == TesterMissionPresentation.compact) {
      return _CompactStrip(
        mission: widget.mission,
        onHideForSession: _hideForSession,
        onHideForToday: _hideForToday,
      );
    }

    return _FullCard(
      mission: widget.mission,
      onHideForSession: _hideForSession,
      onHideForToday: _hideForToday,
    );
  }
}

class _FullCard extends StatelessWidget {
  const _FullCard({
    required this.mission,
    required this.onHideForSession,
    required this.onHideForToday,
  });

  final TesterMissionResult mission;
  final VoidCallback onHideForSession;
  final VoidCallback onHideForToday;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.listSubtitle(context);

    return Container(
      key: const Key('tester_mission_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            mission.title,
            key: const Key('tester_mission_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            TesterMissionCopy.mission,
            key: const Key('tester_mission_mission'),
            style: bodyStyle.copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (mission.stepLabel.isNotEmpty) ...[
            Text(
              mission.stepLabel,
              key: const Key('tester_mission_step_label'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (mission.body.isNotEmpty)
            Text(
              mission.body,
              key: const Key('tester_mission_body'),
              style: bodyStyle.copyWith(height: 1.45),
            ),
          if (mission.footer.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              mission.footer,
              key: const Key('tester_mission_footer'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          _DismissActions(
            onHideForSession: onHideForSession,
            onHideForToday: onHideForToday,
          ),
        ],
      ),
    );
  }
}

class _CompactStrip extends StatelessWidget {
  const _CompactStrip({
    required this.mission,
    required this.onHideForSession,
    required this.onHideForToday,
  });

  final TesterMissionResult mission;
  final VoidCallback onHideForSession;
  final VoidCallback onHideForToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tester_mission_compact_strip'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      key: const Key('tester_mission_compact_title'),
                      style: ArchiveMobileTypography.cardLabel(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      TesterMissionCopy.mission,
                      key: const Key('tester_mission_compact_mission'),
                      style: ArchiveMobileTypography.responsiveHelper(context),
                    ),
                    if (mission.stepLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        mission.stepLabel,
                        key: const Key('tester_mission_compact_step_label'),
                        style: ArchiveMobileTypography.responsiveHelper(
                          context,
                        ),
                      ),
                    ] else if (mission.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        mission.body,
                        key: const Key('tester_mission_compact_body'),
                        style: ArchiveMobileTypography.responsiveHelper(
                          context,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          _DismissActions(
            onHideForSession: onHideForSession,
            onHideForToday: onHideForToday,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _DismissActions extends StatelessWidget {
  const _DismissActions({
    required this.onHideForSession,
    required this.onHideForToday,
    this.compact = false,
  });

  final VoidCallback onHideForSession;
  final VoidCallback onHideForToday;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        TextButton(
          key: const Key('tester_mission_hide_for_now'),
          onPressed: onHideForSession,
          child: Text(
            TesterMissionCopy.hideForNowCta,
            style: compact ? const TextStyle(fontSize: 12) : null,
          ),
        ),
        TextButton(
          key: const Key('tester_mission_hide_for_today'),
          onPressed: onHideForToday,
          child: Text(
            TesterMissionCopy.hideForTodayCta,
            style: compact ? const TextStyle(fontSize: 12) : null,
          ),
        ),
      ],
    );
  }
}
