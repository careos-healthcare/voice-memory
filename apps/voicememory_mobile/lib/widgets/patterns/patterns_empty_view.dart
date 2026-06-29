import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import 'patterns_empty_archive_preview_card.dart';

/// Zero-entry Patterns screen — mind-map preview and two capture actions.
class PatternsEmptyView extends StatelessWidget {
  const PatternsEmptyView({
    super.key,
    this.fillViewport = false,
    this.footer = const [],
  });

  final bool fillViewport;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PatternsEmptyArchivePreviewCard(),
        if (footer.isNotEmpty) ...[
          SizedBox(height: gap),
          ...footer,
        ],
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
