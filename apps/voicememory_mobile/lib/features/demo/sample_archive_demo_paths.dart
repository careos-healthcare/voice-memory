import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../activation/capture_context_tags.dart';
import '../share/archive_share_actions.dart';
import 'demo_share_pack.dart';
import 'sample_archive_copy.dart';

/// Demo path row shown inside Sample Archive only — example data, no journal writes.
class SampleArchiveDemoPath {
  const SampleArchiveDemoPath({
    required this.id,
    required this.title,
    required this.buttonKey,
  });

  final String id;
  final String title;
  final Key buttonKey;
}

/// Navigation helpers for screenshot/review demo paths inside Sample Archive.
abstract final class SampleArchiveDemoPaths {
  SampleArchiveDemoPaths._();

  static const workContextTagId = CaptureContextTagIds.work;

  static const sampleContextRoute = '/sample-archive/context/:tagId';

  static String sampleContextPath(String tagId) =>
      '/sample-archive/context/$tagId';

  static const paths = <SampleArchiveDemoPath>[
    SampleArchiveDemoPath(
      id: 'start',
      title: SampleArchiveCopy.demoPathStartTitle,
      buttonKey: Key('sample_archive_demo_path_start'),
    ),
    SampleArchiveDemoPath(
      id: 'evidence_map',
      title: SampleArchiveCopy.demoPathEvidenceMapTitle,
      buttonKey: Key('sample_archive_demo_path_evidence_map'),
    ),
    SampleArchiveDemoPath(
      id: 'work_context',
      title: SampleArchiveCopy.demoPathWorkContextTitle,
      buttonKey: Key('sample_archive_demo_path_work_context'),
    ),
    SampleArchiveDemoPath(
      id: 'copy_summary',
      title: SampleArchiveCopy.demoPathCopySummaryTitle,
      buttonKey: Key('sample_archive_demo_path_copy_summary'),
    ),
    SampleArchiveDemoPath(
      id: 'back_archive',
      title: SampleArchiveCopy.demoPathBackArchiveTitle,
      buttonKey: Key('sample_archive_demo_path_back_archive'),
    ),
  ];

  static Future<void> scrollToStart(ScrollController controller) async {
    if (!controller.hasClients) return;
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  static Future<void> scrollToEvidenceMap(GlobalKey evidenceMapKey) async {
    final targetContext = evidenceMapKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 300),
      alignment: 0.08,
    );
  }

  static void openWorkContext(BuildContext context) {
    context.push(sampleContextPath(workContextTagId));
  }

  static Future<void> copyDemoSummary(BuildContext context) async {
    final pack = DemoSharePackEngine.build();
    await ArchiveShareActions.copyShareText(
      context,
      text: pack.plainText,
    );
  }

  static void backToArchive(BuildContext context) {
    context.go('/archive-belief');
  }

  static Future<void> runPath(
    BuildContext context, {
    required String pathId,
    required ScrollController scrollController,
    required GlobalKey evidenceMapKey,
  }) async {
    switch (pathId) {
      case 'start':
        await scrollToStart(scrollController);
      case 'evidence_map':
        await scrollToEvidenceMap(evidenceMapKey);
      case 'work_context':
        if (context.mounted) openWorkContext(context);
      case 'copy_summary':
        if (context.mounted) await copyDemoSummary(context);
      case 'back_archive':
        if (context.mounted) backToArchive(context);
    }
  }
}
