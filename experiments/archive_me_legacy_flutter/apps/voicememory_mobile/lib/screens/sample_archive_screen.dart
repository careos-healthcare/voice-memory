import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../features/demo/demo_share_pack.dart';
import '../features/demo/sample_archive_copy.dart';
import '../features/demo/sample_archive_demo_paths.dart';
import '../features/demo/sample_archive_entries.dart';
import '../features/demo/sample_archive_workspace.dart';
import '../features/help/help_reviewer_guide_copy.dart';
import '../widgets/demo/demo_share_pack_card.dart';
import '../widgets/demo/sample_archive_banner.dart';
import '../widgets/demo/sample_archive_demo_paths_card.dart';
import '../widgets/demo/sample_archive_starter_prompts_card.dart';
import '../widgets/demo/sample_archive_tour_card.dart';
import '../widgets/pushed_screen_shell.dart';

/// Optional sample archive — in-memory example data, never mixed with real entries.
class SampleArchiveScreen extends StatefulWidget {
  const SampleArchiveScreen({super.key});

  @override
  State<SampleArchiveScreen> createState() => _SampleArchiveScreenState();
}

class _SampleArchiveScreenState extends State<SampleArchiveScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _evidenceMapKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
        controller: _scrollController,
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          const SampleArchiveBanner(),
          const SampleArchiveStarterPromptsCard(),
          const SampleArchiveTourCard(),
          SampleArchiveDemoPathsCard(
            scrollController: _scrollController,
            evidenceMapKey: _evidenceMapKey,
          ),
          DemoSharePackCard(pack: demoSharePack),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('sample_archive_help_guide_link'),
              onPressed: () => context.push('/help-reviewer-guide'),
              child: const Text(HelpReviewerGuideCopy.sampleArchiveHelpLink),
            ),
          ),
          ...SampleArchiveWorkspace.build(
            context,
            entries,
            evidenceMapKey: _evidenceMapKey,
            onEvidenceMapRowTap: (tagId) =>
                context.push(SampleArchiveDemoPaths.sampleContextPath(tagId)),
          ),
        ],
      ),
    );
  }
}
