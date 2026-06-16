import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../features/memory/treat_as_new.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'keep_exact_details_control.dart';
import 'treat_as_new_control.dart';

/// Recording-screen memory control: shows the current memory scope for
/// the entry about to be saved, and the per-entry choices it allows.
///
/// - automatic / thread-only: current mode plus the "Treat this as new"
///   toggle (off = use current setting).
/// - ask: a calm connect prompt — Connect, or Treat as new.
/// - off: a short notice that the entry saves without connection
///   suggestions. Nothing here can turn memory back on.
/// Calm notice for insight surfaces while memory is off: entries are
/// saved, connections are paused, and one CTA leads to the setting.
class MemoryOffNotice extends StatelessWidget {
  const MemoryOffNotice({super.key, required this.onChangeSetting});

  final VoidCallback onChangeSetting;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryOffNoticeSeen,
      source: 'insights',
      oncePerSession: true,
    );
    return Container(
      key: const Key('memory_off_notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MemoryScopeCopy.offNoticeTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            MemoryScopeCopy.offNoticeBody,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const Key('memory_off_notice_cta'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: onChangeSetting,
            child: const Text(MemoryScopeCopy.offNoticeCta),
          ),
        ],
      ),
    );
  }
}

class MemoryScopeControl extends StatefulWidget {
  const MemoryScopeControl({super.key, this.entryCount});

  /// For analytics counts only.
  final int? entryCount;

  @override
  State<MemoryScopeControl> createState() => _MemoryScopeControlState();
}

class _MemoryScopeControlState extends State<MemoryScopeControl> {
  bool _connectChosen = false;

  void _connect() {
    MemoryScopePolicy.connectApprovedForNextSave = true;
    TreatAsNew.selectedForNextSave = false;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryConnectConfirmed,
      entryCount: widget.entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    setState(() => _connectChosen = true);
  }

  void _treatAsNew() {
    TreatAsNew.selectedForNextSave = true;
    MemoryScopePolicy.connectApprovedForNextSave = false;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryTreatAsNewSelected,
      entryCount: widget.entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    setState(() => _connectChosen = false);
  }

  @override
  Widget build(BuildContext context) {
    final scope = MemoryScopePolicy.scope;
    if (scope == MemoryScope.off) return _offNotice(context);
    if (scope == MemoryScope.ask) return _connectPrompt(context);

    // Automatic / thread-only: one compact current-mode line above the
    // per-entry fresh toggle (toggle off = use current setting). Kept
    // small on purpose — this sits in the fixed area under the record CTA.
    return Column(
      key: const Key('memory_scope_control'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${MemoryScopeCopy.entryControlTitle}: ${scope.label} · '
          '${MemoryScopeCopy.useCurrentSettingLabel}',
          key: const Key('memory_scope_current_mode'),
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        TreatAsNewControl(entryCount: widget.entryCount),
        const SizedBox(height: AppSpacing.xs),
        KeepExactDetailsControl(entryCount: widget.entryCount),
      ],
    );
  }

  Widget _offNotice(BuildContext context) {
    return Container(
      key: const Key('memory_scope_off_entry_notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MemoryScopeCopy.offEntryTitle,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: 2),
          Text(
            MemoryScopeCopy.offEntryBody,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _connectPrompt(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryConnectPromptSeen,
      entryCount: widget.entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      oncePerSession: true,
    );
    final treatAsNewChosen = TreatAsNew.selectedForNextSave;
    return Container(
      key: const Key('memory_connect_prompt'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MemoryScopeCopy.connectPromptTitle,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: 2),
          Text(
            MemoryScopeCopy.connectPromptBody,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          if (_connectChosen) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              MemoryScopeCopy.connectConfirmed,
              key: const Key('memory_connect_confirmed_line'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ] else if (treatAsNewChosen) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              TreatAsNew.helper,
              key: const Key('memory_treat_as_new_chosen_line'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                key: const Key('memory_connect_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _connectChosen ? null : _connect,
                child: const Text(MemoryScopeCopy.connectLabel),
              ),
              TextButton(
                key: const Key('memory_prompt_treat_as_new_button'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: treatAsNewChosen ? null : _treatAsNew,
                child: const Text(MemoryScopeCopy.treatAsNewLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
