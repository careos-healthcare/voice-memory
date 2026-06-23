import 'package:flutter/material.dart';

import '../design/archive_mobile_spacing.dart';
import '../features/demo/demo_share_pack.dart';
import '../features/demo/sample_archive_copy.dart';
import '../features/demo/sample_archive_entries.dart';
import '../features/demo/sample_archive_workspace.dart';
import '../widgets/demo/demo_share_pack_card.dart';
import '../widgets/demo/sample_archive_banner.dart';
import '../widgets/demo/sample_archive_tour_card.dart';
import '../widgets/pushed_screen_shell.dart';

/// Optional sample archive — in-memory example data, never mixed with real entries.
class SampleArchiveScreen extends StatelessWidget {
  const SampleArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = SampleArchiveEntries.build();
    final demoSharePack = DemoSharePackEngine.build();
    return PushedScreenShell(
      title: SampleArchiveCopy.screenTitle,
      doneLabel: SampleArchiveCopy.exitDone,
      fallbackRoute: '/archive-belief',
      body: ListView(
        key: const Key('sample_archive_screen'),
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          const SampleArchiveBanner(),
          const SampleArchiveTourCard(),
          DemoSharePackCard(pack: demoSharePack),
          ...SampleArchiveWorkspace.build(context, entries),
        ],
      ),
    );
  }
}
