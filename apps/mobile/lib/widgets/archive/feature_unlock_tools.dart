import 'dart:async';

import 'package:archiveme_mobile/features/feature_unlock/feature_unlock_service.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/ui/continuity_paywall_section.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Progress or the opened tool, driven by [featureUnlockProvider].
class FeatureUnlockDashboardSlot extends StatelessWidget {
  const FeatureUnlockDashboardSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final scoped =
        context.findAncestorWidgetOfExactType<ProviderScope>() != null ||
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    if (!scoped) return const SizedBox.shrink();
    return const FeatureUnlockDashboardSection();
  }
}

class FeatureUnlockDashboardSection extends ConsumerWidget {
  const FeatureUnlockDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(featureUnlockProvider);
    if (!state.loaded) return const SizedBox.shrink();
    return FeatureUnlockTools(
      state: state,
      onCelebrated: (milestone) {
        unawaited(
          ref.read(featureUnlockProvider.notifier).acknowledge(milestone),
        );
        if (milestone != FeatureUnlockMilestone.theoryEngines) return;
        if (PremiumAccess.current.hasPremiumAccess) return;
        unawaited(showPatternSynthesisPaywall(context));
      },
      onOpenTheoryEngines: () {
        final router = GoRouter.maybeOf(context);
        if (router != null) unawaited(router.push('/theories'));
      },
    );
  }
}

/// Opens the premium sheet after the first pattern highlight.
///
/// Local capture stays available. The sheet offers encrypted cloud backup,
/// automated Obsidian export, and pattern synthesis.
Future<void> showPatternSynthesisPaywall(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: const ContinuityPaywallSection(),
      );
    },
  );
}

class FeatureUnlockTools extends StatelessWidget {
  const FeatureUnlockTools({
    required this.state,
    required this.onCelebrated,
    this.onOpenTheoryEngines,
    super.key,
  });

  final FeatureUnlockState state;
  final ValueChanged<FeatureUnlockMilestone> onCelebrated;
  final VoidCallback? onOpenTheoryEngines;

  static const blindSpotName = 'Blind Spot Analysis';
  static const theoryEngineName = 'Key Themes';

  static String progressLine({
    required int remaining,
    required String toolName,
  }) {
    final noun = remaining == 1 ? 'entry' : 'entries';
    return '$remaining more $noun to unlock $toolName';
  }

  @override
  Widget build(BuildContext context) {
    final celebration = state.pendingCelebrations.isEmpty
        ? null
        : state.pendingCelebrations.first;
    return Column(
      key: const Key('feature_unlock_tools'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (celebration != null)
          _MilestoneCelebration(
            key: ValueKey(celebration),
            message: celebration == FeatureUnlockMilestone.blindSpots
                ? '$blindSpotName is open.'
                : '$theoryEngineName are open.',
            onDone: () => onCelebrated(celebration),
          ),
        _gate(
          context,
          milestone: FeatureUnlockMilestone.blindSpots,
          name: blindSpotName,
          opened: state.canSeeBlindSpots,
          line: 'A reading of what the entries leave out.',
          progressKey: const Key('feature_unlock_blind_spots_progress'),
          toolKey: const Key('feature_unlock_blind_spots'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _gate(
          context,
          milestone: FeatureUnlockMilestone.theoryEngines,
          name: theoryEngineName,
          opened: state.canSeeTheoryEngines,
          line: 'Working lines across the entries you kept.',
          progressKey: const Key('feature_unlock_theory_engines_progress'),
          toolKey: const Key('feature_unlock_theory_engines'),
          onOpen: onOpenTheoryEngines,
        ),
      ],
    );
  }

  Widget _gate(
    BuildContext context, {
    required FeatureUnlockMilestone milestone,
    required String name,
    required bool opened,
    required String line,
    required Key progressKey,
    required Key toolKey,
    VoidCallback? onOpen,
  }) {
    if (opened) {
      return _OpenedTool(
        toolKey: toolKey,
        name: name,
        line: line,
        onOpen: onOpen,
      );
    }
    final remaining = state.remainingFor(milestone);
    return _ProgressMark(
      markKey: progressKey,
      filled: state.entryCount,
      total: milestone == FeatureUnlockMilestone.blindSpots
          ? FeatureUnlockService.blindSpotEntries
          : FeatureUnlockService.theoryEngineEntries,
      label: progressLine(remaining: remaining, toolName: name),
    );
  }
}

class _ProgressMark extends StatelessWidget {
  const _ProgressMark({
    required this.markKey,
    required this.filled,
    required this.total,
    required this.label,
  });

  final Key markKey;
  final int filled;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Column(
      key: markKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < total; index++)
              SizedBox(
                width: 8,
                height: 8,
                child: ColoredBox(
                  color: ink.withValues(alpha: index < filled ? 0.9 : 0.22),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: ink.withValues(alpha: 0.62),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _OpenedTool extends StatelessWidget {
  const _OpenedTool({
    required this.toolKey,
    required this.name,
    required this.line,
    this.onOpen,
  });

  final Key toolKey;
  final String name;
  final String line;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: ink,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          line,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: ink.withValues(alpha: 0.62),
            height: 1.4,
          ),
        ),
      ],
    );
    if (onOpen == null) return KeyedSubtree(key: toolKey, child: body);
    return TextButton(
      key: toolKey,
      onPressed: onOpen,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        foregroundColor: ink,
      ),
      child: body,
    );
  }
}

class _MilestoneCelebration extends StatefulWidget {
  const _MilestoneCelebration({
    required this.message,
    required this.onDone,
    super.key,
  });

  final String message;
  final VoidCallback onDone;

  @override
  State<_MilestoneCelebration> createState() => _MilestoneCelebrationState();
}

class _MilestoneCelebrationState extends State<_MilestoneCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onDone();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Semantics(
            liveRegion: true,
            child: Text(
              widget.message,
              key: const Key('feature_unlock_celebration'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
