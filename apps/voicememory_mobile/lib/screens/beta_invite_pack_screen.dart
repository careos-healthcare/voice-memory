import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/beta_invite/beta_invite_copy.dart';
import '../features/beta_invite/beta_invite_models.dart';
import '../features/beta_invite/beta_invite_store.dart';
import '../features/share/archive_share_actions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../widgets/pushed_screen_shell.dart';

/// Local beta tester invite scripts — copy only, no uploads.
class BetaInvitePackScreen extends StatefulWidget {
  const BetaInvitePackScreen({
    super.key,
    this.store,
  });

  final BetaInviteStore? store;

  @override
  State<BetaInvitePackScreen> createState() => _BetaInvitePackScreenState();
}

class _BetaInvitePackScreenState extends State<BetaInvitePackScreen> {
  BetaInviteStore? _store;
  BetaInviteVariantId _selectedVariant = BetaInviteVariantId.general;

  Future<void> _copyShort() async {
    _store ??= widget.store ?? BetaInviteStore.instance();
    final text = BetaInviteCopy.shortInvite(_selectedVariant);
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: text,
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      await _store!.recordShortCopy(_selectedVariant);
      ArchiveShareActions.showFeedback(context, BetaInviteCopy.shortCopied);
    }
  }

  Future<void> _copyFull() async {
    _store ??= widget.store ?? BetaInviteStore.instance();
    final text = BetaInviteCopy.fullInvite(_selectedVariant);
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: text,
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      await _store!.recordFullCopy(_selectedVariant);
      ArchiveShareActions.showFeedback(context, BetaInviteCopy.fullCopied);
    }
  }

  Future<void> _copyTask() async {
    _store ??= widget.store ?? BetaInviteStore.instance();
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: BetaInviteCopy.testerTask,
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      await _store!.recordTaskCopy(_selectedVariant);
      ArchiveShareActions.showFeedback(context, BetaInviteCopy.taskCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: BetaInviteCopy.screenTitle,
      fallbackRoute: '/support-feedback',
      body: SingleChildScrollView(
        key: const Key('beta_invite_pack_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              BetaInviteCopy.subtitle,
              key: const Key('beta_invite_pack_subtitle'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              BetaInviteCopy.corePositioning,
              key: const Key('beta_invite_pack_positioning'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              BetaInviteCopy.betaSuccessChecklist,
              key: const Key('beta_invite_pack_success_checklist'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              BetaInviteCopy.variantSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              key: const Key('beta_invite_pack_variants'),
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final variant in BetaInviteVariantId.values)
                  ChoiceChip(
                    key: Key('beta_invite_variant_${variant.name}'),
                    label: Text(BetaInviteCopy.variantTitle(variant)),
                    selected: _selectedVariant == variant,
                    onSelected: (_) =>
                        setState(() => _selectedVariant = variant),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              BetaInviteCopy.previewSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: VoiceMemoryCards.standard(
                background: AppColors.surfaceAlt,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    BetaInviteCopy.shortInvite(_selectedVariant),
                    key: const Key('beta_invite_pack_short_preview'),
                    style: ArchiveMobileTypography.explanationBody(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    BetaInviteCopy.longInvite(_selectedVariant),
                    key: const Key('beta_invite_pack_long_preview'),
                    style: ArchiveMobileTypography.explanationBody(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tester task:\n${BetaInviteCopy.testerTask}',
                    key: const Key('beta_invite_pack_task_preview'),
                    style: ArchiveMobileTypography.explanationBody(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'What to report back:\n${BetaInviteCopy.reportBackPrompt}',
                    key: const Key('beta_invite_pack_report_preview'),
                    style: ArchiveMobileTypography.explanationBody(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    BetaInviteCopy.privacyReminder,
                    key: const Key('beta_invite_pack_privacy_reminder'),
                    style: ArchiveMobileTypography.explanationBody(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('beta_invite_copy_short'),
                onPressed: _copyShort,
                child: const Text(BetaInviteCopy.copyShortButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_invite_copy_full'),
                onPressed: _copyFull,
                child: const Text(BetaInviteCopy.copyFullButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_invite_copy_task'),
                onPressed: _copyTask,
                child: const Text(BetaInviteCopy.copyTaskButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_invite_open_beta_outcomes'),
                onPressed: () => context.push('/beta-outcomes'),
                child: const Text(BetaInviteCopy.openBetaOutcomesButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_invite_open_pro_interest'),
                onPressed: () => context.push('/pro-interest'),
                child: const Text(BetaInviteCopy.openProInterestButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
