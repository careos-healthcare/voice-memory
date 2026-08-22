import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_engine.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_navigation.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Shown when a journey reaches 3 supporting evidence moments.
class SignalJourneyCompletionCard extends StatelessWidget {
  const SignalJourneyCompletionCard({
    required this.journey, required this.onKeepWatching, super.key,
    this.onViewPattern,
  });

  final SignalJourney journey;
  final VoidCallback onKeepWatching;
  final VoidCallback? onViewPattern;

  static const _engine = SignalJourneyEngine();

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0FFF4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.signalJourneyCompletionTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.signalJourneyCompletionBody,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          SizedBox(height: gap),
          _section(
            context,
            ConsumerUiCopy.signalJourneyCompletionRepeated,
            _engine.completionRepeated(journey),
          ),
          _section(
            context,
            ConsumerUiCopy.signalJourneyCompletionChanged,
            _engine.completionChanged(journey),
          ),
          _section(
            context,
            ConsumerUiCopy.signalJourneyCompletionWatchNext,
            _engine.completionWatchNext(journey),
          ),
          SizedBox(height: gap),
          FilledButton(
            onPressed: onKeepWatching,
            child: const Text(ConsumerUiCopy.signalJourneyKeepWatching),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (onViewPattern != null)
            OutlinedButton(
              onPressed: onViewPattern,
              child: const Text(ConsumerUiCopy.signalJourneyViewPattern),
            ),
          if (onViewPattern != null) const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: () => SignalJourneyNavigation.recordNextEvidence(
              context,
              prompt: journey.nextPrompt,
            ),
            child: const Text(ConsumerUiCopy.signalJourneyRecordEvidence),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String label, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ArchiveMobileTypography.cardLabel(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: ArchiveMobileTypography.explanationBody(context)),
        ],
      ),
    );
  }
}