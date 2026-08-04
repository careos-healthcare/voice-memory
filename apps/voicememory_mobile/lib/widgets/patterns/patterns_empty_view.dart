import 'package:flutter/material.dart';

import '../../design/archive_responsive_layout.dart';
import '../../features/onboarding/archive_journey_explainer_gates.dart';
import '../../features/onboarding/archive_journey_model.dart';
import '../../widgets/onboarding/archive_journey_explainer_card.dart';
import 'patterns_empty_archive_preview_card.dart';

/// Zero-entry Patterns screen — mind-map preview and two capture actions.
class PatternsEmptyView extends StatelessWidget {
  const PatternsEmptyView({
    super.key,
    this.fillViewport = false,
    this.footer = const [],
    this.showArchiveJourneyExplainer = false,
  });

  final bool fillViewport;
  final List<Widget> footer;
  final bool showArchiveJourneyExplainer;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PatternsEmptyArchivePreviewCard(),
        if (showArchiveJourneyExplainer &&
            ArchiveJourneyExplainerGates.showFullOnPatternsEmpty(
              hasFirstProof: false,
            )) ...[
          SizedBox(height: gap),
          ArchiveJourneyExplainerCard(
            explainer: ArchiveJourneyExplainer.full(),
          ),
        ],
        if (footer.isNotEmpty) ...[SizedBox(height: gap), ...footer],
      ],
    );

    final padded = ArchiveResponsiveLayout.page(
      context: context,
      maxWidth: ArchiveResponsiveLayout.cardMaxWidth,
      child: content,
    );

    return SingleChildScrollView(
      physics: fillViewport
          ? const AlwaysScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      child: padded,
    );
  }
}
