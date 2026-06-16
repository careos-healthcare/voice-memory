import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../product/consumer_ui_copy.dart';
import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';

/// Zero-entry Patterns screen — clear expectation and one CTA.
class PatternsEmptyView extends StatelessWidget {
  const PatternsEmptyView({super.key, this.fillViewport = false});

  final bool fillViewport;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ConsumerUiCopy.patternsEmptyPageTitle,
          style: ArchiveMobileTypography.responsivePageTitle(context),
        ),
        SizedBox(height: gap),
        Text(
          ConsumerUiCopy.patternsEarlyStateBody,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        SizedBox(height: gap + 4),
        FilledButton(
          key: const Key('patterns_empty_record_first_moment'),
          onPressed: () => context.go('/record'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(
            ConsumerUiCopy.patternsEmptyCta,
            style: ArchiveMobileTypography.responsiveCta(context),
          ),
        ),
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
