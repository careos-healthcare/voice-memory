import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/v1_interface/archive_secondary_nav_gates.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_spacing.dart';

/// Secondary Archive links — Discover, Timeline, Search. Hidden until enough evidence.
class ArchiveSecondaryNavLinks extends StatelessWidget {
  const ArchiveSecondaryNavLinks({super.key, required this.entryCount});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    if (!ArchiveSecondaryNavGates.showSecondaryLinks(entryCount: entryCount)) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('archive_secondary_nav_links'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: const Key('archive_secondary_discover'),
          onPressed: () => context.push('/discover-yourself'),
          child: const Text(ConsumerUiCopy.archiveDiscoverPatternsLink),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('archive_secondary_timeline'),
          onPressed: () => context.push('/archive-timeline'),
          child: const Text(ConsumerUiCopy.archiveTimelineLink),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('archive_secondary_search'),
          onPressed: () => context.push('/search'),
          child: const Text(ConsumerUiCopy.archiveSearchLink),
        ),
      ],
    );
  }
}
