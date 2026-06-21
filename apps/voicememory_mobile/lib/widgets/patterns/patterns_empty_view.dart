import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import 'patterns_empty_archive_preview_card.dart';

/// Zero-entry Patterns screen — preview promise and one CTA.
class PatternsEmptyView extends StatelessWidget {
  const PatternsEmptyView({super.key, this.fillViewport = false});

  final bool fillViewport;

  @override
  Widget build(BuildContext context) {
    final content = const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PatternsEmptyArchivePreviewCard(),
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
