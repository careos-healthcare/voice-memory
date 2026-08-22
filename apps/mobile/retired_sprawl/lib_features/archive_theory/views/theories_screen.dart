import 'dart:async';

import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/core/config/theory_tracking_feature_flags.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_theory/citation_playback_launcher.dart';
import 'package:archiveme_mobile/features/archive_theory/evolving_understanding_return_coordinator.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_engine.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/archive_theory/views/theories_view.dart';
import 'package:archiveme_mobile/features/archive_theory/views/theory_page_copy.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_engine.dart';
import 'package:archiveme_mobile/features/insights/widgets/node_graph_viewer.dart';
import 'package:archiveme_mobile/features/insights/widgets/theory_xray_sheet.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';

/// Mobile parity for web `/theories` — working-theory tracker presentation.
class TheoriesScreen extends StatefulWidget {
  const TheoriesScreen({super.key});

  @override
  State<TheoriesScreen> createState() => _TheoriesScreenState();
}

class _TheoriesScreenState extends State<TheoriesScreen> {
  TheoryTrackerReport? _report;
  EvolvingViewSnapshot? _evolving;
  var _reflectionCount = 0;
  var _loading = true;
  List<JournalEntry> _entries = const [];
  final _citationPlayback = const CitationPlaybackLauncher();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(EvolvingUnderstandingReturnCoordinator.onTheoriesVisit());
  }

  Future<void> _load() async {
    if (!TheoryTrackingFeatureFlags.enableTheoryTracking ||
        !AppServices.isInitialized) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final entries = await AppServices.instance.journalStore.loadAll();
    final eligible = ArchiveEvidenceGuard.eligibleEntries(
      entries,
      analyticsSource: 'theories_screen',
    );
    const engine = TheoryTrackerEngine();
    final snapshots = TheorySnapshotStore(AppServices.instance.prefs);
    final report = await engine.build(entries: entries, snapshots: snapshots);
    await EvolvingUnderstandingReturnCoordinator.recordFirstWorkingTheoryIfNeeded(
      report,
    );

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _report = report;
      _evolving = engine.evolvingSnapshot(report);
      _reflectionCount = eligible.length;
      _loading = false;
    });
  }

  Future<void> _onCitationTap(TheoryEvidenceQuote quote) async {
    await _citationPlayback.play(quote: quote, entries: _entries);
  }

  void _onConnectionMapTap(TrackedTheory theory) {
    unawaited(
      showTheoryConnectionGraphSheet(
        context,
        theory: theory,
        onCitationPlay: _onCitationTap,
      ),
    );
  }

  void _onXRayTap(TrackedTheory theory) {
    final inspection = theory.inspection;
    if (inspection == null) return;
    unawaited(
      showTheoryXRaySheet(
        context,
        theoryStatement: theory.statement,
        inspection: inspection,
        entries: _entries,
        hybridSearch: _readHybridSearch(),
        searchRepository: _readSearchRepository(),
      ),
    );
  }

  HybridSearchEngine? _readHybridSearch() {
    try {
      return appProviderContainer.read(hybridSearchEngineProvider);
    } on Object {
      return null;
    }
  }

  MemoryTranscriptSearchRepository? _readSearchRepository() {
    try {
      return appProviderContainer.read(memoryTranscriptSearchRepositoryProvider);
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showXRay = DeveloperSettingsGate.canShowDeveloperSettings;
    return PushedScreenShell(
      title: TheoryPageCopy.title,
      body: _loading
          ? const Center(child: Text(TheoryPageCopy.loadingBody))
          : SingleChildScrollView(
              key: const Key('theories_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    TheoryPageCopy.eyebrow,
                    style: ArchiveMobileTypography.cardLabel(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    TheoryPageCopy.lead,
                    style: ArchiveMobileTypography.explanationBody(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    TheoryPageCopy.disclaimer,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_report != null && _evolving != null)
                    TheoriesView(
                      report: _report!,
                      evolvingSnapshot: _evolving!,
                      reflectionCount: _reflectionCount,
                      onCitationTap: _onCitationTap,
                      onConnectionMapTap: _onConnectionMapTap,
                      onXRayTap: _onXRayTap,
                      showXRay: showXRay,
                    ),
                ],
              ),
            ),
    );
  }
}