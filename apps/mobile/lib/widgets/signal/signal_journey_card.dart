import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_engine.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_navigation.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact signal journey card for Record and Patterns tabs.
class SignalJourneyCard extends StatelessWidget {
  const SignalJourneyCard({
    required this.journey, super.key,
    this.activeLoop,
    this.compact = false,
    this.onViewJourney,
  });

  final SignalJourney journey;
  final LoopMode? activeLoop;
  final bool compact;
  final VoidCallback? onViewJourney;

  static const _engine = SignalJourneyEngine();
  static const _loopEngine = LoopModeEngine();

  @override
  Widget build(BuildContext context) {
    if (!journey.isActive && !journey.isConfirmed) {
      return const SizedBox.shrink();
    }

    final gap = ArchiveResponsiveLayout.gap(context);

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF5FAFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            activeLoop != null
                ? _loopEngine.journeyTitle(activeLoop!)
                : ConsumerUiCopy.signalJourneyTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            activeLoop != null
                ? _loopEngine.journeyRecordBody(activeLoop!)
                : _engine.watchingLine(journey),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            activeLoop != null
                ? _loopEngine.journeyProgressLabel(activeLoop!, journey)
                : _engine.progressLabel(journey),
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _engine.statusLabel(journey.status),
            style: ArchiveMobileTypography.responsiveBody(context),
          ),
          if (!journey.isConfirmed) ...[
            SizedBox(height: gap),
            Text(
              activeLoop != null
                  ? _loopEngine.journeyRecordTitle(activeLoop!)
                  : _engine.recordMoreLine(journey),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          SizedBox(height: gap),
          FilledButton(
            onPressed: () => SignalJourneyNavigation.recordNextEvidence(
              context,
              prompt: journey.nextPrompt,
            ),
            child: const Text(ConsumerUiCopy.signalJourneyRecordEvidence),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed:
                  onViewJourney ??
                  () => SignalJourneyNavigation.openJourneyDetail(context),
              child: const Text(ConsumerUiCopy.signalJourneyViewJourney),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed:
                    onViewJourney ??
                    () => SignalJourneyNavigation.openJourneyDetail(context),
                child: const Text(ConsumerUiCopy.signalJourneyViewJourney),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Patterns tab variant for confirmed journeys.
class SignalJourneyConfirmedCard extends StatelessWidget {
  const SignalJourneyConfirmedCard({required this.journey, super.key});

  final SignalJourney journey;

  static const _engine = SignalJourneyEngine();

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.signalJourneyPatternsConfirmed,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            journey.signalTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _engine.progressLabel(journey),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          if (journey.nextPrompt.trim().isNotEmpty) ...[
            SizedBox(height: gap),
            Text(
              ConsumerUiCopy.signalJourneyRecordNext,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              journey.nextPrompt,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          SizedBox(height: gap),
          OutlinedButton(
            onPressed: () => SignalJourneyNavigation.openJourneyDetail(context),
            child: const Text(ConsumerUiCopy.signalJourneyViewJourney),
          ),
        ],
      ),
    );
  }
}