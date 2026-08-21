import 'package:archiveme_mobile/features/v1_interface/archive_secondary_nav_gates.dart';
import 'package:archiveme_mobile/l10n/localized_consumer_ui.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Secondary Archive links — Discover, Timeline, Search. Hidden until enough evidence.
class ArchiveSecondaryNavLinks extends StatelessWidget {
  const ArchiveSecondaryNavLinks({required this.entryCount, super.key});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    if (!ArchiveSecondaryNavGates.showSecondaryLinks(entryCount: entryCount)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;

    return Column(
      key: const Key('archive_secondary_nav_links'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const Key('archive_secondary_discover'),
          onPressed: () => context.push('/discover-yourself'),
          child: Text(l10n.archiveDiscoverPatternsLink),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('archive_secondary_timeline'),
          onPressed: () => context.push('/archive-timeline'),
          child: Text(l10n.archiveTimelineLink),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('archive_secondary_search'),
          onPressed: () => context.push('/search'),
          child: Text(l10n.archiveSearchLink),
        ),
      ],
    );
  }
}