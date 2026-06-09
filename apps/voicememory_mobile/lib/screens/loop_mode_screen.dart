import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/loop_mode/loop_mode_coordinator.dart';
import '../features/loop_mode/loop_mode_engine.dart';
import '../features/loop_mode/loop_mode_model.dart';
import '../features/prove_enough/prove_enough_evidence_trail_model.dart';
import '../features/prove_enough/prove_enough_evidence_trail_navigation.dart';
import '../features/signal_review/signal_review_coordinator.dart';
import '../product/loop_mode_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/prove_enough/prove_enough_retention_panel.dart';
import '../widgets/prove_enough/loop_trigger_map_section.dart';
import '../widgets/prove_enough/monthly_ambition_pressure_review_section.dart';

/// Loop Mode detail — promise, progress, evidence, prompts.
class LoopModeScreen extends StatefulWidget {
  const LoopModeScreen({super.key});

  @override
  State<LoopModeScreen> createState() => _LoopModeScreenState();
}

class _LoopModeScreenState extends State<LoopModeScreen> {
  static const _engine = LoopModeEngine();

  LoopMode? _loop;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loop = await LoopModeCoordinator.loadActive();
    if (!mounted) return;
    setState(() {
      _loop = loop;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final loop = _loop;
    if (loop == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(title: const Text('Loop Mode')),
        body: const Center(child: Text('No active loop yet.')),
      );
    }

    final status = _engine.progressStatus(loop);
    final statusLabel = _engine.progressStatusLabel(status);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(title: Text(loop.title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Section(
            label: LoopModeCopy.detailPromise,
            body: loop.shortPromise,
          ),
          _Section(
            label: LoopModeCopy.detailProgress,
            body: '${_engine.progressFraction(loop)} · $statusLabel',
          ),
          _Section(
            label: LoopModeCopy.detailNextPrompt,
            body: _engine.nextPrompt(loop),
          ),
          _Section(
            label: LoopModeCopy.detailConfirms,
            body: _engine.wouldConfirmFor(loop),
          ),
          _Section(
            label: LoopModeCopy.detailChallenges,
            body: _engine.wouldChallengeFor(loop),
          ),
          if (loop.isProveEnough) ...[
            const SizedBox(height: AppSpacing.md),
            const LoopTriggerMapSection(),
            ProveEnoughRetentionPanel(),
            const MonthlyAmbitionPressureReviewSection(),
            OutlinedButton(
              onPressed: () => ProveEnoughEvidenceTrailNavigation.open(context),
              child: const Text(ProveEnoughEvidenceTrail.screenTitle),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => context.go(
              '/record?prompt=${Uri.encodeComponent(loop.activePrompt)}&autostart=1',
            ),
            child: Text(
              LoopModeCopy.progressRecordCtaForLoop(loop.id),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => context.push('/signal-journey'),
            child: const Text(LoopModeCopy.detailJourneyLink),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: () async {
              final review =
                  await SignalReviewCoordinator.loadForActiveJourney();
              if (!context.mounted) return;
              if (review != null) {
                context.push('/signal-review');
              }
            },
            child: const Text(LoopModeCopy.detailReviewLink),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
