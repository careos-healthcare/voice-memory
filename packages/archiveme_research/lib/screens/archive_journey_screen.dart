import 'package:flutter/material.dart';

import 'package:voicememory_mobile/features/archive_growth/archive_growth_copy.dart';
import 'package:voicememory_mobile/features/archive_growth/archive_growth_service.dart';
import 'package:voicememory_mobile/features/archive_growth/archive_journey_engine.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/theme/voicememory_colors.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

class ArchiveJourneyScreen extends StatefulWidget {
  const ArchiveJourneyScreen({super.key});

  @override
  State<ArchiveJourneyScreen> createState() => _ArchiveJourneyScreenState();
}

class _ArchiveJourneyScreenState extends State<ArchiveJourneyScreen> {
  ArchiveGrowthSnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snap = await ArchiveGrowthService.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: ArchiveJourneyCopy.journeyTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  ArchiveJourneyCopy.journeySubtitle,
                  style: const TextStyle(color: AppTheme.muted, height: 1.45),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_snapshot!.journey.completedCount} of ${_snapshot!.journey.steps.length} rewards unlocked · '
                  '${_snapshot!.journey.recordingCount} recordings · '
                  '${_snapshot!.journey.daysSinceFirstRecording} days',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 20),
                ..._snapshot!.journey.steps.map(_stepCard),
              ],
            ),
    );
  }

  Widget _stepCard(ArchiveJourneyStep step) {
    final done = step.isComplete;
    final locked = !step.isUnlocked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? VoiceMemoryColors.success.withValues(alpha: 0.5)
                : VoiceMemoryColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_outline
                      : locked
                      ? Icons.lock_outline
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: done ? VoiceMemoryColors.success : AppTheme.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              step.instruction,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
            if (step.isUnlocked && step.reward.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                step.reward,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
