import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../product/consumer_ui_copy.dart';
import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';

/// Warm first-run Patterns screen — clear expectation and one CTA.
class PatternsEmptyView extends StatelessWidget {
  const PatternsEmptyView({
    super.key,
    this.fillViewport = false,
    this.reflectionCount = 0,
  });

  final bool fillViewport;
  final int reflectionCount;

  String get _title {
    if (reflectionCount == 1) return ConsumerUiCopy.patternsOneMomentTitle;
    return ConsumerUiCopy.patternsEmptyPageTitle;
  }

  String get _body {
    if (reflectionCount == 1) return ConsumerUiCopy.patternsOneMomentBody;
    return ConsumerUiCopy.patternsEarlyStateBody;
  }

  String get _cta {
    if (reflectionCount == 1) return ConsumerUiCopy.patternsOneMomentCta;
    return ConsumerUiCopy.patternsEmptyCta;
  }

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _title,
          style: ArchiveMobileTypography.responsivePageTitle(context),
        ),
        SizedBox(height: gap),
        Text(
          _body,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        SizedBox(height: gap + 4),
        FilledButton(
          onPressed: () => context.go('/record'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(
            _cta,
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
