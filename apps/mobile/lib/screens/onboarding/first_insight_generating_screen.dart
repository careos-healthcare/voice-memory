import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/evidence_method/record_entry_providers.dart';
import 'package:archiveme_mobile/features/onboarding/brain_dump_copy.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_onboarding_coordinator.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/evidence_insight_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Post brain-dump loading while encrypted audio uploads and insight generates.
class FirstInsightGeneratingScreen extends ConsumerStatefulWidget {
  const FirstInsightGeneratingScreen({super.key});

  @override
  ConsumerState<FirstInsightGeneratingScreen> createState() =>
      _FirstInsightGeneratingScreenState();
}

class _FirstInsightGeneratingScreenState
    extends ConsumerState<FirstInsightGeneratingScreen> {
  var _startedFinalize = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFinalize());
  }

  Future<void> _maybeFinalize() async {
    if (_startedFinalize) return;
    _startedFinalize = true;

    final session = ref.read(recordEntrySessionProvider);
    if (session.phase == RecordEntryPhase.recording ||
        session.phase == RecordEntryPhase.backgroundPaused) {
      await ref.read(recordEntrySessionNotifierProvider).finishBrainDump();
    }
  }

  Future<void> _continueToArchive() async {
    await AppServices.instance.prefs.setOnboardingCompleted(true);
    onboardingGate.markComplete();
    if (!mounted) return;

    final entries = await AppServices.instance.journal.loadAll();
    if (ExperimentHOnboardingCoordinator.shouldInsertProofStep(
      entryCount: entries.length,
      isPostCapture: true,
    )) {
      context.go(
        ExperimentHOnboardingCoordinator.routeFor(
          source: 'brain_dump_insight',
          entryId: entries.isNotEmpty ? entries.last.id : null,
        ),
      );
      return;
    }

    context.go('/record');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordEntrySessionProvider, (previous, next) {
      if (next.phase == RecordEntryPhase.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Something went wrong.')),
        );
      }
    });

    final session = ref.watch(recordEntrySessionProvider);

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
                  if (session.phase == RecordEntryPhase.complete &&
                      session.insight != null) ...[
                    EvidenceInsightCard(
                      insight: Insight(
                        id: session.insight!.id,
                        insightText: session.insight!.insightText,
                        kind: ArchiveInsightKind.values.asNameMap()[session.insight!.kind ?? ''] ??
                            ArchiveInsightKind.theme,
                        confidenceBand:
                            PatternMatchConfidenceBand.values.asNameMap()[
                                session.insight!.confidenceBand] ??
                            PatternMatchConfidenceBand.weak,
                        citedEntries: const [],
                      ),
                    ),
                  ] else ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      BrainDumpCopy.generatingTitle,
                      textAlign: TextAlign.center,
                      style: OnboardingTypography.title(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      BrainDumpCopy.generatingBody,
                      textAlign: TextAlign.center,
                      style: OnboardingTypography.body(context),
                    ),
                  ],
                  const Spacer(),
                  if (session.phase == RecordEntryPhase.complete)
                    FilledButton(
                      onPressed: _continueToArchive,
                      child: const Text('Continue to my archive'),
                    ),
                  if (session.phase == RecordEntryPhase.error)
                    FilledButton(
                      onPressed: () => context.go('/onboarding/brain-dump'),
                      child: const Text('Try again'),
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