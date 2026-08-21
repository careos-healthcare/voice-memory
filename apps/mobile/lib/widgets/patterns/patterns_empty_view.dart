import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/onboarding/archive_journey_explainer_gates.dart';
import 'package:archiveme_mobile/features/onboarding/archive_journey_model.dart';
import 'package:archiveme_mobile/widgets/onboarding/archive_journey_explainer_card.dart';
import 'package:archiveme_mobile/widgets/patterns/patterns_empty_archive_preview_card.dart';
import 'package:flutter/material.dart';

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