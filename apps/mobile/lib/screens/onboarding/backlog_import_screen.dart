import 'dart:async';

import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/onboarding/backlog_import_copy.dart';
import 'package:archiveme_mobile/features/onboarding/backlog_import_notifier.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_onboarding_coordinator.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/backlog_import_service.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/evidence_insight_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Optional onboarding step — import historical notes with upload progress.
class BacklogImportScreen extends ConsumerWidget {
  const BacklogImportScreen({super.key});

  Future<void> _continueAfterImport(BuildContext context) async {
    final entries = await AppServices.instance.journal.loadAll();
    if (ExperimentHOnboardingCoordinator.shouldInsertProofStep(
      entryCount: entries.length,
      isPostCapture: true,
    )) {
      if (!context.mounted) return;
      context.go(
        ExperimentHOnboardingCoordinator.routeFor(
          source: 'backlog_import',
          entryId: entries.isNotEmpty ? entries.first.id : null,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    context.go(RouteCatalog.recordHome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(backlogImportNotifierProvider);
    final notifier = ref.read(backlogImportNotifierProvider.notifier);
    final isBusy = progress.isActive;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: OnboardingAmbientGlow()),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    BacklogImportCopy.title,
                    textAlign: TextAlign.center,
                    style: OnboardingTypography.title(context),
                  ),
                  SizedBox(height: OnboardingTypography.sectionGap(context)),
                  Text(
                    BacklogImportCopy.subtitle,
                    textAlign: TextAlign.center,
                    style: OnboardingTypography.body(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (progress.insight != null) ...[
                    EvidenceInsightCard(
                      insight: Insight(
                        id: progress.insight!.id,
                        insightText: progress.insight!.insightText,
                        kind:
                            ArchiveInsightKind.values.asNameMap()[progress
                                .insight!
                                .kind] ??
                            ArchiveInsightKind.theme,
                        confidenceBand:
                            PatternMatchConfidenceBand.values.asNameMap()[progress
                                .insight!
                                .confidenceBand] ??
                            PatternMatchConfidenceBand.weak,
                        citedEntries: const [],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (progress.phase != BacklogImportPhase.idle ||
                      progress.totalChunks > 0) ...[
                    Text(
                      BacklogImportCopy.progressLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        key: const Key('backlog_import_progress'),
                        value: progress.totalChunks > 0
                            ? progress.fraction
                            : null,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceAlt,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      progress.statusMessage ??
                          '${progress.processedChunks} of ${progress.totalChunks}',
                      textAlign: TextAlign.center,
                      style: OnboardingTypography.body(context).copyWith(
                        fontSize: OnboardingTypography.bodySize(context) - 1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (progress.phase == BacklogImportPhase.complete &&
                        progress.failedCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          '${progress.failedCount} ${progress.failedCount == 1 ? 'entry' : 'entries'} could not be imported.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.warning),
                        ),
                      ),
                    if (progress.phase == BacklogImportPhase.error)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          progress.errorMessage ?? 'Something went wrong.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.warning),
                        ),
                      ),
                  ] else
                    Text(
                      BacklogImportCopy.idleHint,
                      textAlign: TextAlign.center,
                      style: OnboardingTypography.body(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const Spacer(),
                  if (progress.phase == BacklogImportPhase.complete)
                    FilledButton(
                      key: const Key('backlog_import_continue_button'),
                      onPressed: isBusy
                          ? null
                          : () => _continueAfterImport(context),
                      child: const Text(BacklogImportCopy.continueCta),
                    )
                  else if (progress.phase == BacklogImportPhase.error) ...[
                    FilledButton(
                      key: const Key('backlog_import_retry_button'),
                      onPressed: isBusy
                          ? null
                          : () {
                              notifier.reset();
                              unawaited(notifier.pickAndImport());
                            },
                      child: const Text(BacklogImportCopy.retryCta),
                    ),
                    TextButton(
                      key: const Key('backlog_import_continue_after_error'),
                      onPressed: isBusy
                          ? null
                          : () => _continueAfterImport(context),
                      child: const Text(BacklogImportCopy.continueCta),
                    ),
                  ] else
                    FilledButton(
                      key: const Key('backlog_import_pick_button'),
                      onPressed: isBusy ? null : notifier.pickAndImport,
                      child: const Text(BacklogImportCopy.pickCta),
                    ),
                  if (progress.phase == BacklogImportPhase.idle ||
                      progress.phase == BacklogImportPhase.picking)
                    TextButton(
                      key: const Key('backlog_import_skip_button'),
                      onPressed: isBusy
                          ? null
                          : () => _continueAfterImport(context),
                      child: const Text(BacklogImportCopy.skipCta),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}