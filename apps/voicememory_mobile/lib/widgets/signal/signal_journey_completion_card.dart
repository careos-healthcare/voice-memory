import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/signal_journey/signal_journey_engine.dart';
import '../../features/signal_journey/signal_journey_model.dart';
import '../../features/signal_journey/signal_journey_navigation.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Shown when a journey reaches 3 supporting evidence moments.
class SignalJourneyCompletionCard extends StatelessWidget {
  const SignalJourneyCompletionCard({
    super.key,
    required this.journey,
    required this.onKeepWatching,
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
            child: Text(ConsumerUiCopy.signalJourneyKeepWatching),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (onViewPattern != null)
            OutlinedButton(
              onPressed: onViewPattern,
              child: Text(ConsumerUiCopy.signalJourneyViewPattern),
            ),
          if (onViewPattern != null) const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: () => SignalJourneyNavigation.recordNextEvidence(
              context,
              prompt: journey.nextPrompt,
            ),
            child: Text(ConsumerUiCopy.signalJourneyRecordEvidence),
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
