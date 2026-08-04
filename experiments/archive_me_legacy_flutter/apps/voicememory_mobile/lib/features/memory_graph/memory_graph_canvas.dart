import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../config/experimental_features.dart';
import '../../features/archive_evidence/comparable_evidence_text.dart';
import '../../models/journal_entry.dart';
import '../../l10n/localization_lookup.dart';
import '../../services/app_services.dart';
import '../../services/hallucination_guard/hallucination_guard_service.dart';
import '../../services/notifications/sunday_digest_service.dart';
import '../../shared/ui/animations/canvas_feature_panel.dart';
import '../../shared/ui/glassmorphic_container.dart';
import '../action_plans/action_plan_models.dart';
import '../action_plans/ui/action_plans_overlay.dart';
import '../cold_start/cold_start_engine.dart';
import '../cold_start/guided_spark_prompts.dart';
import '../document_ingestion/document_graph_mapper.dart';
import '../document_ingestion/ui/document_vault_sheet.dart';
import '../ai_engines/models/hypothesis_evolution.dart';
import '../life_dashboard/dashboard_aggregation_engine.dart';
import '../life_dashboard/life_dashboard_overlay.dart';
import '../life_dashboard/dashboard_synthesis_service.dart';
import '../life_simulator/life_simulator_engine.dart';
import '../life_simulator/life_simulator_models.dart';
import '../life_simulator/ui/life_simulator_overlay.dart';
import '../life_story_replay/replay_sync_service.dart';
import '../life_story_replay/ui/life_story_replay_sheet.dart';
import '../codex_press/ui/codex_publish_sheet.dart';
import '../cognitive_analytics/ui/cognitive_analytics_sheet.dart';
import '../persona_forge/ui/persona_studio_sheet.dart';
import '../horizon_lab/horizon_canvas_layer.dart';
import '../horizon_lab/horizon_models.dart';
import '../horizon_lab/ui/horizon_lab_sheet.dart';
import '../mesh_exchange/ui/mesh_exchange_sheet.dart';
import '../whispering_vault/ui/whispering_vault_sheet.dart';
import '../whispering_vault/whispering_vault_controller.dart';
import '../autonomous_muse/autonomous_muse_models.dart';
import '../autonomous_muse/ui/muse_briefing_sheet.dart';
import '../autonomous_muse/ui/muse_settings_sheet.dart';
import '../theme_system/theme_models.dart';
import '../theme_system/visual_theme_tokens.dart';
import '../omni_search/search_graph_focus.dart';
import '../onboarding_future_value/onboarding_future_value_fixtures.dart';
import '../relationships/relationship_graph_models.dart';
import '../semantic_clusters/semantic_cluster.dart';
import '../semantic_clusters/semantic_cluster_store.dart';
import '../semantic_clusters/ui/semantic_clusters_sheet.dart';
import '../tomorrow_return/check_in_reminder_service.dart';
import '../weekly_intelligence/weekly_delta_engine.dart';
import '../weekly_intelligence/weekly_intelligence_sheet.dart';
import '../weekly_intelligence/weekly_intelligence_synthesis_service.dart';
import '../time_machine/temporal_graph_engine.dart';
import '../time_machine/temporal_graph_providers.dart';
import '../time_machine/ui/canvas_time_machine_slider.dart';
import '../sync/encrypted_sync_engine.dart';
import '../sync/sync_status_chip.dart';
import '../cloud_relay_sync/ui/cloud_sync_settings_sheet.dart';
import '../p2p_mesh/mesh_discovery_service.dart';
import '../p2p_mesh/ui/mesh_status_overlay.dart';
import '../p2p_mesh/ui/mesh_ui_models.dart';
import '../p2p_mesh/ui/vault_share_flow.dart';
import '../p2p_mesh/vault_share/vault_share_models.dart';
import '../hivemind/hivemind_models.dart';
import '../hivemind/ui/mesh_studio_sheet.dart';
import '../spatial_nexus/spatial_nexus_models.dart';
import '../spatial_nexus/spatial_nexus_service.dart';
import '../spatial_nexus/ui/spatial_nexus_sheet.dart';
import '../spatial_nexus/ui/spatial_nexus_viewport.dart';
import '../morning_briefing/morning_briefing_models.dart';
import '../morning_briefing/ui/morning_briefing_sheet.dart';
import '../widgets/ui/widget_settings_sheet.dart';
import '../sync/device_pairing_scanner.dart';
import '../connectors/data_sources_sheet.dart';
import '../../services/app_services_providers.dart';
import 'models/manual_graph_service.dart';
import 'rendering/memory_graph_visual_style.dart';
import 'ui/manual_node_sheet.dart';
import '../../ui/screens/life_os/interactive_knowledge_graph_widget.dart';

/// Compact controls that remain visible over the graph on phone layouts.
class MemoryGraphPrimaryToolbar extends StatelessWidget {
  const MemoryGraphPrimaryToolbar({
    super.key,
    required this.onSearch,
    required this.onFilter,
    required this.onMore,
  });

  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Memory Graph controls',
      child: Material(
        key: const Key('memory_graph_primary_toolbar'),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        elevation: 3,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                key: const Key('memory_graph_search'),
                onPressed: onSearch,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                key: const Key('memory_graph_filter'),
                onPressed: onFilter,
                icon: const Icon(Icons.filter_list),
                label: const Text('Filter'),
              ),
            ),
            Semantics(
              button: true,
              label: 'More graph actions',
              hint: 'Opens Advanced Labs and Systems',
              child: IconButton(
                key: const Key('memory_graph_more'),
                tooltip: 'More',
                onPressed: onMore,
                icon: const Icon(Icons.more_horiz),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemoryGraphScrollableActionBar extends StatelessWidget {
  const MemoryGraphScrollableActionBar({
    super.key,
    required this.actions,
    required this.semanticLabel,
    required this.semanticHint,
    required this.semanticActionHint,
  });

  final List<Widget> actions;
  final String semanticLabel;
  final String semanticHint;
  final String semanticActionHint;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

final class _AdvancedGraphAction {
  const _AdvancedGraphAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool enabled;
}

class MemoryGraphCanvas extends ConsumerStatefulWidget {
  const MemoryGraphCanvas({
    super.key,
    required this.graph,
    this.entries = const [],
    this.height,
    this.onNodeSelected,
    this.seedData,
    this.onSparkSelected,
    this.showFirstEntryBurst = false,
    this.dashboardLoader,
    this.lifeSimulatorLoader,
    this.weeklyIntelligenceLoader,
    this.searchGraphFocus,
    this.clusters = const [],
    this.semanticClusterStore,
    this.onClusterPin,
    this.onClusterRename,
    this.onClusterMerge,
    this.onClusterSplit,
    this.actionPlansLoader,
    this.actionPlanCheckIn,
    this.actionPlanPause,
    this.actionPlanResume,
    this.onActionPlanMilestone,
    this.onGenerateActionPlanFromCluster,
    this.onGenerateActionPlanFromTrajectory,
  });

  final PersonalKnowledgeGraph graph;
  final List<JournalEntry> entries;
  final double? height;
  final ValueChanged<GraphNode>? onNodeSelected;
  final ColdStartSeedData? seedData;
  final ValueChanged<GuidedSparkPrompt>? onSparkSelected;
  final bool showFirstEntryBurst;
  final LifeDashboardLoader? dashboardLoader;
  final LifeSimulatorLoader? lifeSimulatorLoader;
  final WeeklyIntelligenceLoader? weeklyIntelligenceLoader;
  final ValueListenable<SearchGraphFocusState>? searchGraphFocus;
  final List<SemanticCluster> clusters;
  final SemanticClusterStore? semanticClusterStore;
  final SemanticClusterPinCallback? onClusterPin;
  final SemanticClusterRenameCallback? onClusterRename;
  final SemanticClusterMergeCallback? onClusterMerge;
  final SemanticClusterSplitCallback? onClusterSplit;
  final ActionPlansLoader? actionPlansLoader;
  final ActionPlanCheckIn? actionPlanCheckIn;
  final ActionPlanLifecycle? actionPlanPause;
  final ActionPlanLifecycle? actionPlanResume;
  final ValueChanged<ActionPlanCheckInResult>? onActionPlanMilestone;
  final FutureOr<void> Function(SemanticCluster cluster)?
  onGenerateActionPlanFromCluster;
  final FutureOr<void> Function(SimulationTrajectory trajectory)?
  onGenerateActionPlanFromTrajectory;

  @override
  ConsumerState<MemoryGraphCanvas> createState() => _MemoryGraphCanvasState();
}

class _MemoryGraphCanvasState extends ConsumerState<MemoryGraphCanvas> {
  // The former chip wall is retired; every secondary action is exposed by More.
  bool get _showLegacyCanvasOverlays => false;

  var _showSample = false;
  var _showTimeMachine = false;
  var _showExternalData = true;
  Set<String> _highlightedNodeIds = const {};
  Set<String> _rejectedNodeIds = const {};
  Set<String> _rejectedEdgeIds = const {};
  DateTime? _timeCutoff;
  PersonalKnowledgeGraph? _historicalGraph;
  StreamSubscription<Set<String>>? _rejectedNodeSubscription;
  StreamSubscription<Set<String>>? _rejectedEdgeSubscription;
  PersonalKnowledgeGraph _manualGraph = PersonalKnowledgeGraph();
  PersonalKnowledgeGraph _externalGraph = PersonalKnowledgeGraph();
  PersonalKnowledgeGraph _documentGraph = PersonalKnowledgeGraph();
  StreamSubscription<int>? _documentGraphSubscription;
  var _showDocumentContext = true;
  Set<String> _searchPulseNodeIds = const {};
  Timer? _searchPulseTimer;
  List<SemanticCluster> _storedClusters = const [];
  String? _focusClusterId;
  int _focusClusterRevision = 0;
  GraphNode? _selectedGraphNode;
  var _showLifeSimulator = false;
  Set<String> _actionPlanBurstNodeIds = const {};
  Set<String> _actionPlanBurstEdgeIds = const {};
  Timer? _actionPlanPulseTimer;
  Timer? _morningPulseTimer;
  String? _morningFocusNodeId;
  int _morningFocusRevision = 0;
  bool _morningSheetOpen = false;
  MuseBriefing? _museBriefing;
  bool _museSheetOpen = false;
  List<TimelineBranch> _horizonBranches = const [];
  double _horizonYear = 5;

  @override
  void initState() {
    super.initState();
    widget.searchGraphFocus?.addListener(_applySearchFocus);
    _effectiveClusterStore?.addListener(_loadClusters);
    unawaited(_loadClusters());
    if (AppServices.isInitialized) {
      final semantic = AppServices.instance.localSemanticStore;
      semantic.manualGraph().then((graph) {
        if (mounted) setState(() => _manualGraph = graph);
      });
      semantic.externalGraph().then((graph) {
        if (mounted) setState(() => _externalGraph = graph);
      });
      final documentOverlay = AppServices.instance.documentGraphOverlayStore;
      documentOverlay.load().then((snapshot) {
        if (mounted) setState(() => _documentGraph = snapshot.graph);
      });
      _documentGraphSubscription = documentOverlay.revisions.listen((_) {
        documentOverlay.load().then((snapshot) {
          if (mounted) setState(() => _documentGraph = snapshot.graph);
        });
      });
      semantic.rejectedNodeIds().then((ids) {
        if (mounted) setState(() => _rejectedNodeIds = ids);
      });
      semantic.rejectedEdgeIds().then((ids) {
        if (mounted) setState(() => _rejectedEdgeIds = ids);
      });
      _rejectedNodeSubscription = semantic.rejectedNodeChanges.listen((ids) {
        if (mounted) setState(() => _rejectedNodeIds = ids);
      });
      _rejectedEdgeSubscription = semantic.rejectedEdgeChanges.listen((ids) {
        if (mounted) setState(() => _rejectedEdgeIds = ids);
      });
      final muse = AppServices.instance.autonomousMuseService.latestBriefing();
      if (muse != null) {
        _museBriefing = muse;
      }
    }
  }

  @override
  void didUpdateWidget(covariant MemoryGraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchGraphFocus != widget.searchGraphFocus) {
      oldWidget.searchGraphFocus?.removeListener(_applySearchFocus);
      widget.searchGraphFocus?.addListener(_applySearchFocus);
      _applySearchFocus();
    }
    final oldStore = _clusterStoreFor(oldWidget);
    final newStore = _effectiveClusterStore;
    if (oldStore != newStore) {
      oldStore?.removeListener(_loadClusters);
      newStore?.addListener(_loadClusters);
      unawaited(_loadClusters());
    }
  }

  @override
  void dispose() {
    widget.searchGraphFocus?.removeListener(_applySearchFocus);
    _effectiveClusterStore?.removeListener(_loadClusters);
    _searchPulseTimer?.cancel();
    _actionPlanPulseTimer?.cancel();
    _morningPulseTimer?.cancel();
    unawaited(_rejectedNodeSubscription?.cancel());
    unawaited(_rejectedEdgeSubscription?.cancel());
    unawaited(_documentGraphSubscription?.cancel());
    super.dispose();
  }

  List<SemanticCluster> get _clusters =>
      widget.clusters.isNotEmpty ? widget.clusters : _storedClusters;

  SemanticClusterStore? get _effectiveClusterStore => _clusterStoreFor(widget);

  SemanticClusterStore? _clusterStoreFor(MemoryGraphCanvas target) =>
      target.semanticClusterStore ??
      (AppServices.isInitialized
          ? AppServices.instance.semanticClusterStore
          : null);

  Future<void> _loadClusters() async {
    final store = _effectiveClusterStore;
    if (store == null) {
      if (mounted && _storedClusters.isNotEmpty) {
        setState(() => _storedClusters = const []);
      }
      return;
    }
    final clusters = await store.list();
    if (mounted && identical(store, _effectiveClusterStore)) {
      setState(() => _storedClusters = clusters);
    }
  }

  void _selectCluster(SemanticCluster cluster, {bool openSummary = false}) {
    setState(() {
      _highlightedNodeIds = cluster.nodeIds.toSet();
      _focusClusterId = cluster.id;
      _focusClusterRevision++;
    });
    if (AppServices.isInitialized) {
      AppServices.instance.autonomousMuseService.markClusterVisited(cluster.id);
    }
    if (openSummary) unawaited(_showClusters(context, initial: cluster.id));
  }

  Future<void> _pinCluster(SemanticCluster cluster, bool pinned) async {
    final callback = widget.onClusterPin;
    if (callback != null) {
      await callback(cluster, pinned);
    } else {
      await _effectiveClusterStore?.pin(cluster.id, pinned);
    }
    await _syncClusters();
    await _loadClusters();
  }

  Future<void> _renameCluster(SemanticCluster cluster, String title) async {
    final callback = widget.onClusterRename;
    if (callback != null) {
      await callback(cluster, title);
    } else {
      await _effectiveClusterStore?.rename(cluster.id, title);
    }
    await _syncClusters();
    await _loadClusters();
  }

  Future<void> _mergeClusters(
    SemanticCluster cluster,
    SemanticCluster other,
  ) async {
    final callback = widget.onClusterMerge;
    if (callback != null) {
      await callback(cluster, other);
    } else {
      await _effectiveClusterStore?.merge([cluster.id, other.id]);
    }
    await _syncClusters();
    await _loadClusters();
  }

  Future<void> _splitCluster(SemanticCluster cluster) async {
    final callback = widget.onClusterSplit;
    if (callback != null) {
      await callback(cluster);
    } else {
      final store = _effectiveClusterStore;
      final ids = cluster.nodeIds.toList()..sort();
      if (store == null || ids.length < 4) return;
      final midpoint = ids.length ~/ 2;
      await store.split(cluster.id, [
        ids.sublist(0, midpoint),
        ids.sublist(midpoint),
      ]);
    }
    await _syncClusters();
    await _loadClusters();
  }

  Future<void> _syncClusters() async {
    if (!AppServices.isInitialized) return;
    final services = AppServices.instance;
    final engine = services.e2eeSyncEngine;
    if (engine != null) {
      await services.semanticClusterSyncCoordinator.recordCurrent(engine);
    }
  }

  Future<void> _showClusters(
    BuildContext context, {
    String? initial,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .38),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .9,
      child: SemanticClustersSheet(
        clusters: _clusters,
        graph: _displayedGraph,
        initialClusterId: initial,
        onClusterSelected: (cluster) {
          _selectCluster(cluster);
          Navigator.of(sheetContext).pop();
        },
        onPin: widget.onClusterPin != null || _effectiveClusterStore != null
            ? _pinCluster
            : null,
        onRename:
            widget.onClusterRename != null || _effectiveClusterStore != null
            ? _renameCluster
            : null,
        onMerge: widget.onClusterMerge != null || _effectiveClusterStore != null
            ? _mergeClusters
            : null,
        onSplit: widget.onClusterSplit != null || _effectiveClusterStore != null
            ? _splitCluster
            : null,
        onTrySmallSteps:
            widget.onGenerateActionPlanFromCluster == null &&
                !AppServices.isInitialized
            ? null
            : (cluster) async {
                final callback = widget.onGenerateActionPlanFromCluster;
                if (callback != null) {
                  await callback(cluster);
                } else {
                  final services = AppServices.instance;
                  final plan = await services.actionPlanGeneratorService
                      .generateFromCluster(cluster, _displayedGraph);
                  await services.actionPlanEngine.create(plan);
                }
                if (!mounted || !sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                await _showActionPlans(this.context);
              },
        onShare: AppServices.isInitialized
            ? (cluster) => VaultShareFlow.showCluster(
                sheetContext,
                cluster: cluster,
                graph: _displayedGraph,
              )
            : null,
      ),
    ),
  );

  void _applySearchFocus() {
    final nodeId = widget.searchGraphFocus?.value.nodeId;
    _searchPulseTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _highlightedNodeIds = nodeId == null ? const {} : {nodeId};
      _searchPulseNodeIds = nodeId == null ? const {} : {nodeId};
      if (nodeId != null) _focusClusterId = null;
    });
    if (nodeId != null) {
      _searchPulseTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _searchPulseNodeIds = const {});
      });
    }
  }

  Future<void> _showMorningBriefing(
    MorningBriefing briefing, {
    bool automatic = false,
  }) async {
    if (_morningSheetOpen || !mounted) return;
    final service = AppServices.instance.morningBriefingService;
    if (service == null) return;
    if (automatic && !await service.shouldPresent()) return;
    if (!mounted) return;
    _morningSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => FractionallySizedBox(
          heightFactor: .92,
          child: MorningBriefingSheet(
            briefing: briefing,
            loadAudio: () => service.audioFor(briefing),
            onStartDayFocus: (target) {
              _focusMorningTarget(target);
              unawaited(service.markPresented());
            },
            onSnooze: service.snooze,
            onJumpToGraph: (target) {
              _focusMorningTarget(target);
              unawaited(service.markPresented());
              Navigator.of(sheetContext).pop();
            },
            onClose: () {
              unawaited(service.markPresented());
              Navigator.of(sheetContext).pop();
            },
          ),
        ),
      );
      final snoozedUntil = await service.store.snoozedUntil();
      if (snoozedUntil == null ||
          !snoozedUntil.isAfter(DateTime.now().toUtc())) {
        await service.markPresented();
      }
    } finally {
      _morningSheetOpen = false;
    }
  }

  void _focusMorningTarget(String? targetId) {
    if (targetId == null || !mounted) return;
    final graphHasNode = _displayedGraph.nodes.any(
      (node) => node.id == targetId,
    );
    if (!graphHasNode) {
      final cluster = _clusters
          .where((candidate) => candidate.id == targetId)
          .firstOrNull;
      if (cluster != null) {
        _selectCluster(cluster);
      }
      return;
    }
    _morningPulseTimer?.cancel();
    setState(() {
      _morningFocusNodeId = targetId;
      _morningFocusRevision++;
      _highlightedNodeIds = {targetId};
      _searchPulseNodeIds = {targetId};
      _focusClusterId = null;
    });
    _morningPulseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _searchPulseNodeIds = const {});
    });
  }

  Future<void> _showMuseBriefing({bool automatic = false}) async {
    final briefing = _museBriefing;
    if (briefing == null || _museSheetOpen || _morningSheetOpen || !mounted) {
      return;
    }
    final service = AppServices.instance.autonomousMuseService;
    if (automatic && !service.shouldPresent(briefing)) return;
    _museSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => FractionallySizedBox(
          heightFactor: .88,
          child: MuseBriefingSheet(
            briefing: briefing,
            onOpenNode: (nodeId) {
              _focusMorningTarget(nodeId);
              service.markPresented(briefing);
              Navigator.of(sheetContext).pop();
            },
            onOpenActionPlan: (_) {
              service.markPresented(briefing);
              Navigator.of(sheetContext).pop();
              unawaited(_showActionPlans(context));
            },
            onClose: () {
              service.markPresented(briefing);
              Navigator.of(sheetContext).pop();
            },
          ),
        ),
      );
      service.markPresented(briefing);
    } finally {
      _museSheetOpen = false;
    }
  }

  Future<void> _showMuseSettings(BuildContext context) async {
    final service = AppServices.instance.autonomousMuseService;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .9,
        child: MuseSettingsSheet(
          initialGovernance: service.governance(),
          onSave: service.updateGovernance,
          onTriggerSweep: () async {
            final result = await service.runSweep(force: true);
            final briefing = result.briefing;
            if (briefing != null && mounted) {
              setState(() => _museBriefing = briefing);
            }
            return result;
          },
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

  PersonalKnowledgeGraph get _unfilteredGraph {
    final base = !_showSample
        ? widget.graph
        : PersonalKnowledgeGraph(
            schemaVersion: widget.graph.schemaVersion,
            nodes: [
              ...widget.graph.nodes,
              ...OnboardingFutureValueFixtures.sample.graph.nodes,
            ],
            edges: [
              ...widget.graph.edges,
              ...OnboardingFutureValueFixtures.sample.graph.edges,
            ],
            trajectories: [
              ...widget.graph.trajectories,
              ...OnboardingFutureValueFixtures.sample.graph.trajectories,
            ],
            materialization: widget.graph.materialization,
          );
    final nodes = {for (final node in base.nodes) node.id: node};
    nodes.addEntries(_manualGraph.nodes.map((node) => MapEntry(node.id, node)));
    nodes.addEntries(
      _externalGraph.nodes.map((node) => MapEntry(node.id, node)),
    );
    if (_showDocumentContext) {
      nodes.addEntries(
        _documentGraph.nodes.map((node) => MapEntry(node.id, node)),
      );
    }
    final edges = {for (final edge in base.edges) edge.id: edge};
    edges.addEntries(_manualGraph.edges.map((edge) => MapEntry(edge.id, edge)));
    edges.addEntries(
      _externalGraph.edges.map((edge) => MapEntry(edge.id, edge)),
    );
    if (_showDocumentContext) {
      edges.addEntries(
        _documentGraph.edges.map((edge) => MapEntry(edge.id, edge)),
      );
    }
    return PersonalKnowledgeGraph(
      schemaVersion: base.schemaVersion,
      nodes: nodes.values,
      edges: edges.values,
      trajectories: base.trajectories,
      materialization: base.materialization,
    );
  }

  ManualGraphService? get _manualService => !AppServices.isInitialized
      ? null
      : ManualGraphService(
          graphStore: AppServices.instance.personalKnowledgeGraphStore,
          semanticStore: AppServices.instance.localSemanticStore,
        );

  Future<void> _createManualNode(Offset _) async {
    final service = _manualService;
    if (service == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ManualNodeSheet(
        imageEngine: AppServices.isInitialized
            ? AppServices.instance.encryptedImageEngine
            : null,
        onSave: (draft) {
          unawaited(
            service.createNode(draft).then((node) async {
              final mediaSync = AppServices.isInitialized
                  ? AppServices.instance.mediaSyncCoordinator
                  : null;
              if (mediaSync != null) {
                for (final attachment in draft.mediaAttachments) {
                  try {
                    await mediaSync.enqueueGraphNodeAttachment(
                      nodeId: node.id,
                      attachment: attachment,
                    );
                  } on Object {
                    // The encrypted local media remains authoritative and the
                    // outbox can be retried after sync becomes available.
                  }
                }
              }
              final extraction = AppServices.isInitialized
                  ? AppServices.instance.visionExtractionService
                  : null;
              final fusion = AppServices.isInitialized
                  ? AppServices.instance.visionGraphFusionService
                  : null;
              if (extraction != null && fusion != null) {
                for (final attachment in draft.mediaAttachments) {
                  try {
                    final result = await extraction.extract(attachment);
                    await fusion.fuse(attachment: attachment, result: result);
                  } on Object {
                    // The manual truth anchor is already durable. Vision
                    // enrichment remains best-effort and can retry later.
                  }
                }
              }
              final graph = await service.semanticStore.manualGraph();
              if (mounted) setState(() => _manualGraph = graph);
            }),
          );
        },
      ),
    );
  }

  Future<void> _connectManualNodes(GraphNode source, GraphNode target) async {
    final service = _manualService;
    if (service == null) return;
    await service.connect(source: source, target: target);
    final graph = await service.semanticStore.manualGraph();
    if (mounted) setState(() => _manualGraph = graph);
  }

  PersonalKnowledgeGraph get _displayedGraph {
    final base = _unfilteredGraph;
    final temporal = _timeCutoff == null
        ? base
        : _historicalGraph ?? graphAtTime(base, _timeCutoff!);
    final nodes = temporal.nodes
        .where(
          (node) =>
              !_rejectedNodeIds.contains(node.id) &&
              (_showExternalData || node.origin != NodeOrigin.external),
        )
        .toList();
    final nodeIds = nodes.map((node) => node.id).toSet();
    return PersonalKnowledgeGraph(
      schemaVersion: temporal.schemaVersion,
      nodes: nodes,
      edges: temporal.edges
          .where(
            (edge) =>
                !_rejectedEdgeIds.contains(edge.id) &&
                nodeIds.contains(edge.sourceNodeId) &&
                nodeIds.contains(edge.targetNodeId),
          )
          .toList(),
      trajectories: temporal.trajectories
          .where(
            (trajectory) =>
                nodeIds.contains(trajectory.subjectNodeId) &&
                (trajectory.relatedNodeId == null ||
                    nodeIds.contains(trajectory.relatedNodeId)),
          )
          .toList(),
      materialization: temporal.materialization,
      clock: temporal.clock,
    );
  }

  Future<void> _selectHistoricalTime(DateTime targetTime) async {
    final target = targetTime.toUtc();
    setState(() {
      _timeCutoff = target;
      _historicalGraph = null;
    });
    ref.read(canvasTargetTimeProvider.notifier).show(target);
    if (!AppServices.isInitialized) return;
    final graph = await TemporalGraphEngine(
      semanticStore: AppServices.instance.localSemanticStore,
      historyStore: AppServices.instance.temporalGraphHistoryStore,
    ).reconstruct(currentGraph: _unfilteredGraph, targetTime: target);
    if (!mounted || _timeCutoff != target) return;
    setState(() => _historicalGraph = graph);
  }

  void _returnToPresent() {
    ref.read(canvasTargetTimeProvider.notifier).present();
    setState(() {
      _timeCutoff = null;
      _historicalGraph = null;
    });
  }

  Set<String> get _burstNodeIds => widget.showFirstEntryBurst
      ? widget.graph.nodes
            .where(
              (node) =>
                  node.type == NodeType.journalEntry ||
                  node.evidence.any(
                    (item) => item.entryId.startsWith('cold-start-'),
                  ),
            )
            .map((node) => node.id)
            .toSet()
      : const {};

  Set<String> get _burstEdgeIds => widget.showFirstEntryBurst
      ? widget.graph.edges
            .where(
              (edge) =>
                  _burstNodeIds.contains(edge.sourceNodeId) ||
                  _burstNodeIds.contains(edge.targetNodeId),
            )
            .map((edge) => edge.id)
            .toSet()
      : const {};

  bool get _canShowActionPlans =>
      widget.actionPlansLoader != null ||
      widget.actionPlanCheckIn != null ||
      widget.actionPlanPause != null ||
      widget.actionPlanResume != null ||
      ActionPlansOverlay.hasDefaultServices;

  Future<void> _showActionPlans(BuildContext context) =>
      showCanvasFeaturePanel<void>(
        context: context,
        routeName: 'small-steps',
        builder: (panelContext) => ActionPlansOverlay(
          load: widget.actionPlansLoader,
          checkIn: widget.actionPlanCheckIn,
          pause: widget.actionPlanPause,
          resume: widget.actionPlanResume,
          onClose: () => Navigator.of(panelContext).pop(),
          onShowOnGraph: (nodeId) {
            setState(() => _highlightedNodeIds = {nodeId});
            Navigator.of(panelContext).pop();
          },
          onCheckInResult: (result) {
            if (!mounted || result.reinforcedNodeIds.isEmpty) return;
            setState(
              () => _highlightedNodeIds = result.reinforcedNodeIds.toSet(),
            );
          },
          onMilestone: _celebrateActionPlanMilestone,
        ),
      );

  Future<void> _showDocumentVault(
    BuildContext context, {
    String? focusNodeId,
  }) async {
    if (!AppServices.isInitialized) return;
    final controller = await AppServices.instance.documentIngestionService
        .createController();
    DocumentCitation? citation;
    if (focusNodeId != null) {
      citation = (await AppServices.instance.documentGraphOverlayStore.load())
          .citations[focusNodeId];
      if (citation != null) {
        controller.selectDocument(citation.documentId);
        controller.toggleChunk(citation.chunkIndex);
      }
    }
    if (!context.mounted) return;
    await showCanvasFeaturePanel<void>(
      context: context,
      routeName: 'document-vault',
      builder: (panelContext) => DocumentVaultSheet(
        controller: controller,
        onClose: () => Navigator.of(panelContext).pop(),
        onBackgroundRequested: () => Navigator.of(panelContext).pop(),
        onFocusNode: (nodeId) {
          Navigator.of(panelContext).pop();
          _focusDocumentTarget(nodeId);
        },
        onFocusCluster: (clusterId) {
          Navigator.of(panelContext).pop();
          final cluster = _clusters
              .where((candidate) => candidate.id == clusterId)
              .firstOrNull;
          if (cluster != null) _selectCluster(cluster);
        },
      ),
    );
  }

  void _focusDocumentTarget(String nodeId) {
    _morningPulseTimer?.cancel();
    setState(() {
      _morningFocusNodeId = nodeId;
      _morningFocusRevision++;
      _highlightedNodeIds = {nodeId};
      _searchPulseNodeIds = {nodeId};
      _focusClusterId = null;
    });
    _morningPulseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _searchPulseNodeIds = const {});
    });
  }

  Future<void> _showLifeStoryReplay(BuildContext context) async {
    if (!AppServices.isInitialized) return;
    final services = AppServices.instance;
    await LifeStoryReplaySheet.show(
      context,
      service: services.replaySyncService,
      generate: services.generateLifeStoryReplay,
      onCameraTarget: _applyReplayCameraTarget,
      onExport: () async {
        final output = File(
          '${Directory.systemTemp.path}/'
          'life-story-${DateTime.now().millisecondsSinceEpoch}.vstory',
        );
        final encrypted = await services.lifeStoryReplayStore.exportEncrypted(
          output,
        );
        await Share.shareXFiles([
          XFile(encrypted.path, mimeType: 'application/octet-stream'),
        ], subject: 'Encrypted Cinematic Life Story');
      },
      onOpenCodex: services.codexPublicationService == null
          ? null
          : () => unawaited(
              showCodexPublishSheet(
                context: context,
                service: services.codexPublicationService!,
                clusters: _clusters,
              ),
            ),
    );
    if (mounted) {
      setState(() {
        _highlightedNodeIds = const {};
        _morningFocusNodeId = null;
        _focusClusterId = null;
      });
    }
  }

  void _applyReplayCameraTarget(ReplayCameraTarget target) {
    if (!mounted) return;
    setState(() {
      _highlightedNodeIds = target.nodeIds.toSet();
      _searchPulseNodeIds = target.nodeIds.toSet();
      _morningFocusNodeId = target.nodeIds.firstOrNull;
      _morningFocusRevision = target.revision;
      _focusClusterId = target.clusterIds.firstOrNull;
      _focusClusterRevision = target.revision;
    });
  }

  Future<void> _showMeshExchange(
    BuildContext context,
    PersonalKnowledgeGraph graph,
  ) async {
    final services = AppServices.instance;
    final exchange = services.meshExchangeService;
    final validator = services.meshImportValidator;
    if (exchange == null || validator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local Mesh Exchange is unavailable.')),
      );
      return;
    }
    final personas = await services.personaForgeService.list();
    if (!context.mounted) return;
    await MeshExchangeSheet.show(
      context,
      exchange: exchange,
      validator: validator,
      graph: graph,
      clusters: _clusters,
      personas: personas,
      onPackageReady: (package) async {
        final file = File(
          '${Directory.systemTemp.path}/mesh-${package.exchangeId}.vmesh',
        );
        await file.writeAsBytes(package.bytes, flush: true);
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'application/octet-stream'),
        ], subject: 'Encrypted Mesh Exchange package');
      },
    );
  }

  Future<void> _showWhisperingVault(BuildContext context) async {
    final services = AppServices.instance;
    final controller = WhisperingVaultController(
      whisper: services.localWhisperService,
      storage: services.audioVaultStorage,
      mapper: services.audioGraphMapper,
    );
    try {
      await WhisperingVaultSheet.show(
        context,
        controller: controller,
        onNodeSelected: _focusDocumentTarget,
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showHivemindStatus(BuildContext context) async {
    final router = AppServices.instance.hivemindMeshRouter;
    if (router == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The Hivemind is unavailable.')),
      );
      return;
    }
    final capabilities = await router.capabilities();
    if (!context.mounted) return;
    await MeshStudioSheet.show(
      context: context,
      builder: (_) => StreamBuilder<List<HivemindPeerState>>(
        stream: router.peers,
        initialData: router.currentPeers,
        builder: (context, snapshot) => MeshStudioSheet(
          peers: snapshot.data ?? const [],
          capabilities: capabilities,
          governance: router.governance,
          onGovernanceChanged: router.updateGovernance,
          onReconcile: () async {
            await AppServices.instance.hivemindSyncEngine?.reconcileNow();
          },
          onManageNearby: () => unawaited(_showMeshStatus(context)),
        ),
      ),
    );
  }

  Future<void> _showSpatialNexus(
    BuildContext context,
    PersonalKnowledgeGraph graph,
  ) async {
    final service = AppServices.instance.spatialNexusService;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The Spatial Nexus is unavailable.')),
      );
      return;
    }
    final capabilities = await service.renderer.capabilities();
    if (!context.mounted) return;

    SpatialScene scene(SpatialEnvironmentPreset preset) =>
        service.renderer.buildScene(
          graph: graph,
          clusters: _clusters,
          horizonBranches: _horizonBranches,
          preset: preset,
        );

    await SpatialNexusSheet.show(
      context,
      initialPreset: service.preferences.preset,
      capabilities: capabilities,
      initialSpatialAudioEnabled: service.preferences.spatialAudioEnabled,
      onPresetChanged: (preset) => service.updatePreferences(
        SpatialNexusPreferences(
          preset: preset,
          spatialAudioEnabled: service.preferences.spatialAudioEnabled,
        ),
      ),
      onSpatialAudioChanged: (enabled) => service.updatePreferences(
        SpatialNexusPreferences(
          preset: service.preferences.preset,
          spatialAudioEnabled: enabled,
        ),
      ),
      onEnterImmersive: () async {
        final currentScene = scene(service.preferences.preset);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Spatial Nexus')),
              body: SpatialNexusViewport(
                renderer: service.renderer,
                scene: currentScene,
                sound: service.sound,
                onNodeSelected: (nodeId) {
                  final node = graph.nodes
                      .where((candidate) => candidate.id == nodeId)
                      .firstOrNull;
                  if (node != null) widget.onNodeSelected?.call(node);
                },
              ),
            ),
          ),
        );
      },
      onExportSnapshot: () async {
        final file = File(
          '${Directory.systemTemp.path}/archive-spatial-'
          '${DateTime.now().toUtc().millisecondsSinceEpoch}.spatial.json',
        );
        await service.exportPortableSnapshot(
          scene(service.preferences.preset),
          file,
        );
        try {
          await Share.shareXFiles([
            XFile(file.path, mimeType: 'application/json'),
          ], subject: 'Private Spatial Nexus snapshot');
        } finally {
          if (await file.exists()) await file.delete();
        }
      },
    );
  }

  Future<void> _showMeshStatus(BuildContext context) async {
    final controller = AppServices.instance.meshController;
    final discovery = AppServices.instance.meshDiscoveryService;
    if (controller == null || discovery == null) return;
    try {
      await controller.start();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nearby sync unavailable: $error')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await showCanvasFeaturePanel<void>(
      context: context,
      routeName: 'nearby-mesh',
      builder: (panelContext) => StreamBuilder<List<MeshPeerViewState>>(
        stream: controller.views,
        initialData: controller.currentViews,
        builder: (context, snapshot) => FutureBuilder<List<SharedVaultBranch>>(
          future:
              AppServices.instance.sharedVaultBranchStore?.list() ??
              Future.value(const []),
          builder: (context, branches) => MeshStatusSheet(
            availability: discovery.state == MeshDiscoveryState.active
                ? MeshAvailability.available
                : MeshAvailability.scanning,
            peers: snapshot.data ?? const [],
            sharedBranches: branches.data ?? const [],
            onOpenBranch: (branch) => _showSharedBranch(panelContext, branch),
            onClose: () => Navigator.of(panelContext).pop(),
            onPair: (peer) => _runMeshAction(
              panelContext,
              () => controller.beginPairing(peer),
            ),
            onConfirmPairing: (peer, confirmed) => _runMeshAction(
              panelContext,
              () => controller.confirmPairing(peer, confirmed),
            ),
            onRetrySync: (peer) => _runMeshAction(
              panelContext,
              () => controller.synchronize(peer),
            ),
            onBeam: (peer) => _runMeshAction(
              panelContext,
              () => controller.synchronize(peer),
            ),
            onRevoke: (peer) =>
                _runMeshAction(panelContext, () => controller.revoke(peer)),
            onImportShare: () => _runMeshAction(
              panelContext,
              () => VaultShareFlow.importShare(panelContext),
            ),
            onScanQr: () => _scanMeshQr(panelContext),
            onShowQr: () => _showMeshQr(panelContext),
            onHaptic: (event) {
              switch (event) {
                case MeshHapticEvent.selection:
                  unawaited(HapticFeedback.selectionClick());
                  return;
                case MeshHapticEvent.confirmation:
                  unawaited(HapticFeedback.mediumImpact());
                  return;
                case MeshHapticEvent.warning:
                  unawaited(HapticFeedback.heavyImpact());
                  return;
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _scanMeshQr(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .72),
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * .86,
        ),
        child: DevicePairingScanner(
          onPayload: (payload) {
            final controller = AppServices.instance.meshController;
            if (controller != null) {
              unawaited(
                _runMeshAction(
                  context,
                  () => controller.beginPairingInvitation(payload),
                ),
              );
            }
          },
        ),
      ),
    ),
  );

  Future<void> _showMeshQr(BuildContext context) async {
    final controller = AppServices.instance.meshController;
    if (controller == null) return;
    final invitation = await controller.createPairingInvitation();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pair nearby device'),
        content: Semantics(
          label: 'Encrypted pairing QR code. Expires in two minutes.',
          image: true,
          child: SizedBox.square(
            dimension: 240,
            child: QrImageView(data: invitation.encode()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSharedBranch(
    BuildContext context,
    SharedVaultBranch branch,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Read-only shared branch'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Attributed to ${branch.attribution.signerId}. '
              'This copy cannot modify your personal graph.',
            ),
            const SizedBox(height: 12),
            for (final cluster in branch.clusters)
              ListTile(
                leading: const Icon(Icons.bubble_chart_outlined),
                title: Text(cluster.title),
                subtitle: Text('${cluster.nodeIds.length} linked memories'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _runMeshAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Nearby sync failed: $error')));
      }
    }
  }

  void _celebrateActionPlanMilestone(ActionPlanCheckInResult result) {
    _actionPlanPulseTimer?.cancel();
    setState(() {
      _highlightedNodeIds = result.reinforcedNodeIds.toSet();
      _actionPlanBurstNodeIds = result.reinforcedNodeIds.toSet();
      _actionPlanBurstEdgeIds = result.reinforcedEdgeIds.toSet();
    });
    widget.onActionPlanMilestone?.call(result);
    _actionPlanPulseTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _actionPlanBurstNodeIds = const {};
        _actionPlanBurstEdgeIds = const {};
      });
    });
  }

  SimulationTarget? _lifeSimulatorTarget(PersonalKnowledgeGraph graph) {
    final graphNodeIds = graph.nodes.map((node) => node.id).toSet();
    final selected = _selectedGraphNode;
    if (selected != null && graphNodeIds.contains(selected.id)) {
      return selected.type == NodeType.habit
          ? SimulationTarget.habit(selected.id, displayLabel: selected.label)
          : SimulationTarget.graphNode(
              selected.id,
              displayLabel: selected.label,
            );
    }
    final clusters =
        _clusters
            .where(
              (cluster) =>
                  cluster.nodeIds.any(graphNodeIds.contains) &&
                  cluster.nodeIds.isNotEmpty,
            )
            .toList()
          ..sort((a, b) {
            final velocity = b.activityVelocity.compareTo(a.activityVelocity);
            return velocity != 0 ? velocity : a.id.compareTo(b.id);
          });
    if (clusters case [final cluster, ...]) {
      return SimulationTarget.semanticCluster(
        cluster.id,
        displayLabel: cluster.title,
      );
    }
    final habit = graph.nodes
        .where((node) => node.type == NodeType.habit)
        .firstOrNull;
    if (habit != null) {
      return SimulationTarget.habit(habit.id, displayLabel: habit.label);
    }
    final first = graph.nodes.firstOrNull;
    return first == null
        ? null
        : SimulationTarget.graphNode(first.id, displayLabel: first.label);
  }

  Future<CounterfactualScenario> _loadLifeSimulation(
    PersonalKnowledgeGraph graph,
    SimulationTarget target,
    SimulationPath alternativePath,
  ) async {
    final supplied = widget.lifeSimulatorLoader;
    if (supplied != null) return supplied(target, alternativePath);
    final services = AppServices.isInitialized ? AppServices.instance : null;
    final hypotheses = services == null
        ? const <HypothesisEvolution>[]
        : await services.localSemanticStore.activeHypotheses(
            confidenceBelow: 101,
            limit: 50,
          );
    final local = const LifeSimulatorEngine().compare(
      graph: graph,
      target: target,
      alternativePath: alternativePath,
      clusters: _clusters,
      hypotheses: hypotheses,
    );
    if (services == null) return local;
    final synthesized = await services.lifeSimulatorSynthesisService.synthesize(
      scenario: local,
      graph: graph,
    );
    await services.lifeSimulatorStore.upsert(synthesized);
    return synthesized;
  }

  Future<void> _showGraphSearch(
    BuildContext context,
    PersonalKnowledgeGraph graph,
  ) async {
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalized = query.trim().toLowerCase();
          final matches = graph.nodes
              .where(
                (node) =>
                    normalized.isEmpty ||
                    node.label.toLowerCase().contains(normalized),
              )
              .take(30)
              .toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search memories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('memory_graph_search_field'),
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search nodes',
                      ),
                      onChanged: (value) => setSheetState(() => query = value),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final node = matches[index];
                          return ListTile(
                            key: Key('memory_graph_search_result_${node.id}'),
                            leading: const Icon(Icons.hub_outlined),
                            title: Text(node.label),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              setState(() {
                                _selectedGraphNode = node;
                                _highlightedNodeIds = {node.id};
                              });
                              widget.onNodeSelected?.call(node);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showGraphFilters(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void update(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Graph filters',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  SwitchListTile(
                    key: const Key('memory_graph_filter_documents'),
                    secondary: const Icon(Icons.menu_book_outlined),
                    title: const Text('Document context'),
                    subtitle: const Text('Show memories linked to documents'),
                    value: _showDocumentContext,
                    onChanged: (value) =>
                        update(() => _showDocumentContext = value),
                  ),
                  SwitchListTile(
                    key: const Key('memory_graph_filter_external'),
                    secondary: const Icon(Icons.sensors_outlined),
                    title: const Text('External data'),
                    subtitle: const Text(
                      'Show connected health and media data',
                    ),
                    value: _showExternalData,
                    onChanged: (value) =>
                        update(() => _showExternalData = value),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAdvancedLabsSheet(
    BuildContext context,
    List<_AdvancedGraphAction> actions,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  'Advanced Labs & Systems',
                  key: const Key('memory_graph_more_sheet_title'),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  key: const Key('memory_graph_more_actions'),
                  children: [
                    for (final action in actions)
                      ListTile(
                        leading: Icon(action.icon),
                        title: Text(action.title),
                        subtitle: action.subtitle == null
                            ? null
                            : Text(action.subtitle!),
                        enabled: action.enabled,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: !action.enabled
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => action.onTap(),
                                );
                              },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appLocalizationsOf(context);
    final visualTokens =
        Theme.of(context).extension<VisualThemeTokens>() ??
        VisualThemeTokens.resolve(
          ThemePreferences.defaultPreferences,
          Theme.of(context).brightness,
        );
    final graphVisualStyle = MemoryGraphVisualStyle.fromTokens(visualTokens);
    final graph = _displayedGraph;
    final latestMorningBriefing = AppServices.isInitialized
        ? ref.watch(morningBriefingProvider).value
        : null;
    final localToday = DateTime.now();
    final morningBriefing =
        latestMorningBriefing != null &&
            latestMorningBriefing.localDay.year == localToday.year &&
            latestMorningBriefing.localDay.month == localToday.month &&
            latestMorningBriefing.localDay.day == localToday.day
        ? latestMorningBriefing
        : null;
    if (enableExperimentalFeatures &&
        morningBriefing != null &&
        !_morningSheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_showMorningBriefing(morningBriefing, automatic: true));
        }
      });
    }
    final museBriefing = _museBriefing;
    if (enableExperimentalFeatures &&
        museBriefing != null &&
        !_museSheetOpen &&
        !_morningSheetOpen &&
        AppServices.instance.autonomousMuseService.shouldPresent(
          museBriefing,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showMuseBriefing(automatic: true));
      });
    }
    final simulatorTarget = _lifeSimulatorTarget(graph);
    final spark = GuidedSparkPrompts.forEntryCount(
      widget.entries.length,
      seed: widget.seedData,
    );
    final dates =
        _unfilteredGraph.nodes
            .expand((node) => node.evidence)
            .map((item) => item.observedAt)
            .toList()
          ..sort();
    final hasTimeRange = dates.length > 1 && dates.first.isBefore(dates.last);
    final isHistorical = _timeCutoff != null;
    final markers = AppServices.isInitialized
        ? ref.watch(temporalGraphMarkersProvider)
        : const <DateTime>[];
    final syncState = AppServices.isInitialized
        ? ref.watch(encryptedSyncStateProvider).value ??
              EncryptedSyncState.disabled
        : EncryptedSyncState.disabled;
    final meshPeers = AppServices.isInitialized
        ? ref.watch(meshPeerViewsProvider).value ?? const <MeshPeerViewState>[]
        : const <MeshPeerViewState>[];
    final meshDiscoveryState = AppServices.isInitialized
        ? ref.watch(meshDiscoveryStateProvider).value ??
              MeshDiscoveryState.stopped
        : MeshDiscoveryState.stopped;
    final meshAvailability = switch (meshDiscoveryState) {
      MeshDiscoveryState.stopped => MeshAvailability.unavailable,
      MeshDiscoveryState.searching => MeshAvailability.scanning,
      MeshDiscoveryState.active => MeshAvailability.available,
      MeshDiscoveryState.error => MeshAvailability.unavailable,
    };
    final hasSampleGraphAction =
        widget.entries.length < GuidedSparkPrompts.maxEntryCount;
    // Kept only until the retired overlay implementation is removed entirely.
    const overlayTop = 48.0;
    const overlayStep = 48.0;
    final sampleGraphTop =
        overlayTop + (morningBriefing != null ? overlayStep : 0);
    final sampleBadgeTop = sampleGraphTop + overlayStep;
    final leftActionTop =
        sampleGraphTop +
        (hasSampleGraphAction ? overlayStep : 0) +
        (hasSampleGraphAction && _showSample ? overlayStep : 0);
    final advancedActions = <_AdvancedGraphAction>[
      _AdvancedGraphAction(
        icon: Icons.dashboard_customize_outlined,
        title: 'Graph overview',
        subtitle: '${graph.nodes.length} connected nodes',
        onTap: () => _showOverview(context),
      ),
      _AdvancedGraphAction(
        icon: Icons.space_dashboard_outlined,
        title: l10n.memoryGraphLifeDashboard,
        subtitle: 'Open the full life dashboard',
        onTap: () => _showLifeDashboard(context, graph),
      ),
      if (hasSampleGraphAction)
        _AdvancedGraphAction(
          icon: _showSample ? Icons.visibility_off_outlined : Icons.visibility,
          title: _showSample
              ? l10n.memoryGraphClosePreview
              : l10n.memoryGraphPreview,
          subtitle: 'Toggle the illustrative sample graph',
          onTap: () => setState(() => _showSample = !_showSample),
        ),
      _AdvancedGraphAction(
        icon: Icons.alt_route,
        title: l10n.memoryGraphLifeSimulator,
        subtitle: 'Explore an alternative path',
        enabled: simulatorTarget != null,
        onTap: () => setState(() => _showLifeSimulator = true),
      ),
      _AdvancedGraphAction(
        icon: Icons.spa_outlined,
        title: l10n.memoryGraphSmallSteps,
        subtitle: 'Turn a pattern into an action plan',
        enabled: _canShowActionPlans,
        onTap: () => _showActionPlans(context),
      ),
      _AdvancedGraphAction(
        icon: Icons.change_circle_outlined,
        title: l10n.memoryGraphWeekly,
        subtitle: 'Review weekly intelligence',
        onTap: () => _showWeeklyIntelligence(context, graph),
      ),
      _AdvancedGraphAction(
        icon: Icons.bubble_chart_outlined,
        title: l10n.memoryGraphClusters(_clusters.length),
        subtitle: 'Inspect semantic clusters',
        onTap: () => _showClusters(context),
      ),
      if (hasTimeRange)
        _AdvancedGraphAction(
          icon: _showTimeMachine ? Icons.close : Icons.history,
          title: _showTimeMachine
              ? l10n.memoryGraphCloseRewind
              : l10n.memoryGraphTimeMachine,
          subtitle: 'Rewind the graph through time',
          onTap: () {
            if (_showTimeMachine) _returnToPresent();
            setState(() => _showTimeMachine = !_showTimeMachine);
          },
        ),
      if (AppServices.isInitialized &&
          AppServices.instance.memoryGraphWidgetService != null)
        _AdvancedGraphAction(
          icon: Icons.widgets_outlined,
          title: l10n.memoryGraphWidgets,
          subtitle: 'Configure home and lock screen widgets',
          onTap: () => WidgetSettingsSheet.show(
            context,
            service: AppServices.instance.memoryGraphWidgetService!,
          ),
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.library_books_outlined,
          title: l10n.memoryGraphDocuments,
          subtitle: 'Open the encrypted document vault',
          onTap: () => _showDocumentVault(context),
        ),
      if (AppServices.isInitialized &&
          AppServices.instance.syncIdentity != null &&
          AppServices.instance.cloudRelaySyncEngine != null)
        _AdvancedGraphAction(
          icon: Icons.cloud_sync_outlined,
          title: 'Encrypted cloud sync',
          subtitle: syncState.name,
          onTap: () => CloudSyncSettingsSheet.show(
            context,
            identity: AppServices.instance.syncIdentity!,
            engine: AppServices.instance.cloudRelaySyncEngine!,
          ),
        ),
      if (AppServices.isInitialized &&
          AppServices.instance.meshController != null)
        _AdvancedGraphAction(
          icon: Icons.hub_outlined,
          title: 'P2P mesh status',
          subtitle:
              '${meshPeers.length} nearby peers · ${meshAvailability.name}',
          onTap: () => _showHivemindStatus(context),
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.tune,
          title: 'Connected data sources',
          subtitle: 'Manage health and media connectors',
          onTap: () => DataSourcesSheet.show(
            context,
            health: AppServices.instance.healthKitConnector,
            spotify: AppServices.instance.spotifyConnector,
            showExternalNodes: _showExternalData,
            onExternalVisibilityChanged: (value) {
              if (mounted) setState(() => _showExternalData = value);
            },
            onDataChanged: () {
              unawaited(
                AppServices.instance.localSemanticStore.externalGraph().then((
                  graph,
                ) {
                  if (mounted) setState(() => _externalGraph = graph);
                }),
              );
            },
          ),
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.movie_filter_outlined,
          title: 'Life Story Replay',
          subtitle: 'Play a cinematic life story',
          onTap: () => _showLifeStoryReplay(context),
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.psychology_alt_outlined,
          title: 'Mind Mirror',
          subtitle: 'Open cognitive analytics',
          onTap: () => CognitiveAnalyticsSheet.show(
            context,
            engine: AppServices.instance.cognitiveMetricsEngine,
          ),
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.theater_comedy_outlined,
          title: 'Persona Forge',
          subtitle: 'Explore local personas',
          onTap: () async {
            final services = AppServices.instance;
            final clusters = await services.semanticClusterStore.list();
            if (!context.mounted) return;
            await PersonaStudioSheet.show(
              context,
              service: services.personaForgeService,
              knowledgeRouter: services.personaKnowledgeRouter,
              clusters: clusters,
            );
          },
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.share_location_outlined,
          title: 'Mesh Exchange',
          subtitle: 'Share graph branches nearby',
          onTap: () => _showMeshExchange(context, graph),
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.mic_external_on_outlined,
          title: 'Whispering Vault',
          subtitle: 'Open encrypted voice storage',
          onTap: () => _showWhisperingVault(context),
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.auto_awesome_outlined,
          title: 'Autonomous Muse',
          subtitle: 'Configure local discovery sweeps',
          onTap: () => _showMuseSettings(context),
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.account_tree_outlined,
          title: 'Horizon Lab',
          subtitle: 'Model possible future branches',
          enabled: graph.nodes.isNotEmpty,
          onTap: () async {
            final divergence =
                _selectedGraphNode ??
                graph.nodes.firstWhere(
                  (node) => node.archivedAt == null,
                  orElse: () => graph.nodes.first,
                );
            final services = AppServices.instance;
            await HorizonLabSheet.show(
              context,
              service: services.horizonLabService,
              simulation: services.horizonSimulationService,
              divergenceNode: divergence,
              clusters: _clusters,
              onLayerChanged: (branches, year) {
                if (mounted) {
                  setState(() {
                    _horizonBranches = branches;
                    _horizonYear = year;
                  });
                }
              },
            );
          },
        ),
      if (AppServices.isInitialized)
        _AdvancedGraphAction(
          icon: Icons.view_in_ar_outlined,
          title: 'Spatial Nexus',
          subtitle: 'Open the immersive graph view',
          enabled: graph.nodes.isNotEmpty,
          onTap: () => _showSpatialNexus(context, graph),
        ),
    ];
    return Stack(
      key: const Key('memory_graph_canvas'),
      children: [
        InteractiveKnowledgeGraphWidget(
          graph: graph,
          clusters: _clusters,
          onClusterSelected: (cluster) =>
              _selectCluster(cluster, openSummary: true),
          focusClusterId: _focusClusterId,
          focusClusterRevision: _focusClusterRevision,
          entries: widget.entries,
          encryptedImageEngine: AppServices.isInitialized
              ? AppServices.instance.encryptedImageEngine
              : null,
          visualStyle: graphVisualStyle,
          height: widget.height,
          onNodeSelected: (node) {
            if (node.origin == NodeOrigin.document) {
              unawaited(_showDocumentVault(context, focusNodeId: node.id));
              return;
            }
            setState(() => _selectedGraphNode = node);
            widget.onNodeSelected?.call(node);
          },
          highlightedNodeIds: _highlightedNodeIds,
          burstNodeIds: {
            ..._burstNodeIds,
            ..._searchPulseNodeIds,
            ..._actionPlanBurstNodeIds,
          },
          burstEdgeIds: {..._burstEdgeIds, ..._actionPlanBurstEdgeIds},
          focusNodeId:
              _morningFocusNodeId ?? widget.searchGraphFocus?.value.nodeId,
          focusRevision: _morningFocusNodeId == null
              ? widget.searchGraphFocus?.value.revision ?? 0
              : _morningFocusRevision,
          onEmptySpaceLongPress: isHistorical ? null : _createManualNode,
          onManualConnection: isHistorical ? null : _connectManualNodes,
          readOnly: isHistorical,
          targetTime: _timeCutoff,
          spatialOverlayBuilder:
              !enableExperimentalFeatures || _horizonBranches.isEmpty
              ? null
              : (layout) => HorizonCanvasLayer(
                  branches: _horizonBranches,
                  year: _horizonYear,
                  pivotByBranchId: {
                    for (final branch in _horizonBranches)
                      if (layout.positions[branch.divergenceNodeId] != null)
                        branch.id: layout.positions[branch.divergenceNodeId]!,
                  },
                ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: MemoryGraphPrimaryToolbar(
            onSearch: () => _showGraphSearch(context, graph),
            onFilter: () => _showGraphFilters(context),
            onMore: () => _showAdvancedLabsSheet(context, advancedActions),
          ),
        ),
        if (enableExperimentalFeatures && morningBriefing != null)
          Positioned(
            left: 12,
            top: 68,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (MediaQuery.sizeOf(context).width - 24).clamp(0, 320),
              ),
              child: ActionChip(
                key: const Key('memory_graph_morning_briefing'),
                avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                label: const Text('Morning briefing'),
                onPressed: () => _showMorningBriefing(morningBriefing),
              ),
            ),
          ),
        if (_showSample)
          Positioned(
            right: 12,
            top: enableExperimentalFeatures && morningBriefing != null
                ? 116
                : 68,
            child: Chip(
              key: const Key('sample_graph_overlay_badge'),
              avatar: const Icon(Icons.science_outlined, size: 18),
              label: Text(l10n.memoryGraphSampleBadge),
            ),
          ),
        if (_showLegacyCanvasOverlays) ...[
          if (morningBriefing != null)
            Positioned(
              left: 8,
              top: overlayTop,
              child: MorningBriefingCard(
                briefing: morningBriefing,
                onPressed: () => _showMorningBriefing(morningBriefing),
              ),
            ),
          Positioned(
            right: 8,
            top: 48,
            child: Semantics(
              button: true,
              label: 'Open graph overview',
              child: ActionChip(
                key: const Key('memory_graph_overview_chip'),
                avatar: const Icon(
                  Icons.dashboard_customize_outlined,
                  size: 18,
                ),
                label: Text(l10n.memoryGraphNodeCount(graph.nodes.length)),
                onPressed: () => _showOverview(context),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: leftActionTop,
            child: Semantics(
              button: true,
              label: 'Open Life Simulator',
              child: ActionChip(
                key: const Key('life_simulator_open'),
                avatar: const Icon(Icons.alt_route, size: 18),
                label: Text(l10n.memoryGraphLifeSimulator),
                onPressed: simulatorTarget == null
                    ? null
                    : () => setState(() => _showLifeSimulator = true),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: leftActionTop + overlayStep,
            child: Semantics(
              button: true,
              label: 'Open small steps',
              child: ActionChip(
                key: const Key('action-plans-open'),
                avatar: const Icon(Icons.spa_outlined, size: 18),
                label: Text(l10n.memoryGraphSmallSteps),
                onPressed: _canShowActionPlans
                    ? () => _showActionPlans(context)
                    : null,
              ),
            ),
          ),
          if (AppServices.isInitialized &&
              AppServices.instance.memoryGraphWidgetService != null)
            Positioned(
              left: 8,
              top: leftActionTop + (overlayStep * 2),
              child: Semantics(
                button: true,
                label: 'Configure home and lock screen widgets',
                child: ActionChip(
                  key: const Key('memory-graph-widgets-open'),
                  avatar: const Icon(Icons.widgets_outlined, size: 18),
                  label: Text(l10n.memoryGraphWidgets),
                  onPressed: () => WidgetSettingsSheet.show(
                    context,
                    service: AppServices.instance.memoryGraphWidgetService!,
                  ),
                ),
              ),
            ),
          if (AppServices.isInitialized)
            Positioned(
              left: 8,
              top: leftActionTop + (overlayStep * 3),
              child: Semantics(
                button: true,
                label: 'Open encrypted document vault',
                child: ActionChip(
                  key: const Key('document-vault-open'),
                  avatar: const Icon(Icons.library_books_outlined, size: 18),
                  label: Text(l10n.memoryGraphDocuments),
                  onPressed: () => _showDocumentVault(context),
                ),
              ),
            ),
          Positioned(
            right: 8,
            top: 144,
            child: ActionChip(
              key: const Key('weekly_intelligence_open'),
              avatar: const Icon(Icons.change_circle_outlined, size: 18),
              label: Text(l10n.memoryGraphWeekly),
              onPressed: () => _showWeeklyIntelligence(context, graph),
            ),
          ),
          Positioned(
            right: 8,
            top: 192,
            child: Semantics(
              button: true,
              label: 'Open semantic clusters',
              child: ActionChip(
                key: const Key('semantic-clusters-open'),
                avatar: const Icon(Icons.bubble_chart_outlined, size: 18),
                label: Text(l10n.memoryGraphClusters(_clusters.length)),
                onPressed: () => _showClusters(context),
              ),
            ),
          ),
          if (hasTimeRange)
            Positioned(
              right: 8,
              top: 240,
              child: ActionChip(
                key: const Key('canvas-time-machine-toggle'),
                avatar: Icon(
                  _showTimeMachine ? Icons.close : Icons.history,
                  size: 18,
                ),
                label: Text(
                  _showTimeMachine
                      ? l10n.memoryGraphCloseRewind
                      : l10n.memoryGraphTimeMachine,
                ),
                onPressed: () {
                  if (_showTimeMachine) _returnToPresent();
                  setState(() => _showTimeMachine = !_showTimeMachine);
                },
              ),
            ),
          if (AppServices.isInitialized &&
              AppServices.instance.syncIdentity != null &&
              AppServices.instance.cloudRelaySyncEngine != null)
            Positioned(
              right: 8,
              top: hasTimeRange ? 288 : 240,
              child: SyncStatusChip(
                state: syncState,
                onPressed: () => CloudSyncSettingsSheet.show(
                  context,
                  identity: AppServices.instance.syncIdentity!,
                  engine: AppServices.instance.cloudRelaySyncEngine!,
                ),
              ),
            ),
          if (AppServices.isInitialized &&
              AppServices.instance.meshController != null)
            Positioned(
              right: 8,
              top: hasTimeRange ? 336 : 288,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: MeshStatusOverlay(
                  availability: meshAvailability,
                  peers: meshPeers,
                  onPressed: () => _showHivemindStatus(context),
                ),
              ),
            ),
          if (AppServices.isInitialized)
            Positioned(
              left: 8,
              right: 8,
              top: hasTimeRange ? 384 : 336,
              child: Align(
                alignment: Alignment.centerRight,
                child: GlassmorphicContainer(
                  key: const Key('memory_graph_glass_toolbar'),
                  radius: BorderRadius.circular(24),
                  padding: EdgeInsets.zero,
                  fillColor: visualTokens.glassFill,
                  blurSigma: visualTokens.blurSigma,
                  opacity: visualTokens.glassOpacity,
                  refractionColors: [
                    visualTokens.glassBorderStart,
                    visualTokens.glassBorderEnd,
                  ],
                  renderQuality: _graphGlassQuality(visualTokens.glassEffects),
                  child: MemoryGraphScrollableActionBar(
                    semanticLabel: l10n.memoryGraphActionBarLabel,
                    semanticHint: l10n.memoryGraphActionBarHint,
                    semanticActionHint: l10n.memoryGraphActionButtonHint,
                    actions: [
                      IconButton(
                        key: const Key('document-context-filter-toggle'),
                        tooltip: _showDocumentContext
                            ? 'Hide document context'
                            : 'Show document context',
                        onPressed: () => setState(
                          () => _showDocumentContext = !_showDocumentContext,
                        ),
                        icon: Icon(
                          _showDocumentContext
                              ? Icons.menu_book
                              : Icons.menu_book_outlined,
                        ),
                      ),
                      IconButton(
                        key: const Key('external-data-filter-toggle'),
                        tooltip: _showExternalData
                            ? 'Hide external data'
                            : 'Show external data',
                        onPressed: () => setState(
                          () => _showExternalData = !_showExternalData,
                        ),
                        icon: Icon(
                          _showExternalData
                              ? Icons.sensors
                              : Icons.sensors_off_outlined,
                        ),
                      ),
                      IconButton(
                        key: const Key('data-sources-open'),
                        tooltip: 'Manage data sources',
                        onPressed: () => DataSourcesSheet.show(
                          context,
                          health: AppServices.instance.healthKitConnector,
                          spotify: AppServices.instance.spotifyConnector,
                          showExternalNodes: _showExternalData,
                          onExternalVisibilityChanged: (value) {
                            if (mounted) {
                              setState(() => _showExternalData = value);
                            }
                          },
                          onDataChanged: () {
                            unawaited(
                              AppServices.instance.localSemanticStore
                                  .externalGraph()
                                  .then((graph) {
                                    if (mounted) {
                                      setState(() => _externalGraph = graph);
                                    }
                                  }),
                            );
                          },
                        ),
                        icon: const Icon(Icons.tune),
                      ),
                      IconButton(
                        key: const Key('life-story-replay-open'),
                        tooltip: 'Play cinematic life story',
                        onPressed: () => _showLifeStoryReplay(context),
                        icon: const Icon(Icons.movie_filter_outlined),
                      ),
                      IconButton(
                        key: const Key('cognitive-analytics-open'),
                        tooltip: 'Open the Mind Mirror',
                        onPressed: () => CognitiveAnalyticsSheet.show(
                          context,
                          engine: AppServices.instance.cognitiveMetricsEngine,
                        ),
                        icon: const Icon(Icons.psychology_alt_outlined),
                      ),
                      IconButton(
                        key: const Key('persona-studio-open'),
                        tooltip: 'Open the Persona Forge',
                        onPressed: () async {
                          final services = AppServices.instance;
                          final clusters = await services.semanticClusterStore
                              .list();
                          if (!context.mounted) return;
                          await PersonaStudioSheet.show(
                            context,
                            service: services.personaForgeService,
                            knowledgeRouter: services.personaKnowledgeRouter,
                            clusters: clusters,
                          );
                        },
                        icon: const Icon(Icons.theater_comedy_outlined),
                      ),
                      IconButton(
                        key: const Key('mesh-exchange-open'),
                        tooltip: 'Open the Mesh Exchange',
                        onPressed: () => _showMeshExchange(context, graph),
                        icon: const Icon(Icons.share_location_outlined),
                      ),
                      IconButton(
                        key: const Key('whispering-vault-open'),
                        tooltip: 'Open the Whispering Vault',
                        onPressed: () => _showWhisperingVault(context),
                        icon: const Icon(Icons.mic_external_on_outlined),
                      ),
                      IconButton(
                        key: const Key('autonomous-muse-open'),
                        tooltip: 'Open Autonomous Muse settings',
                        onPressed: () => _showMuseSettings(context),
                        icon: const Icon(Icons.auto_awesome_outlined),
                      ),
                      IconButton(
                        key: const Key('horizon-lab-open'),
                        tooltip: 'Open the Horizon Lab',
                        onPressed: graph.nodes.isEmpty
                            ? null
                            : () async {
                                final divergence =
                                    _selectedGraphNode ??
                                    graph.nodes.firstWhere(
                                      (node) => node.archivedAt == null,
                                      orElse: () => graph.nodes.first,
                                    );
                                final services = AppServices.instance;
                                await HorizonLabSheet.show(
                                  context,
                                  service: services.horizonLabService,
                                  simulation: services.horizonSimulationService,
                                  divergenceNode: divergence,
                                  clusters: _clusters,
                                  onLayerChanged: (branches, year) {
                                    if (mounted) {
                                      setState(() {
                                        _horizonBranches = branches;
                                        _horizonYear = year;
                                      });
                                    }
                                  },
                                );
                              },
                        icon: const Icon(Icons.account_tree_outlined),
                      ),
                      IconButton(
                        key: const Key('spatial-nexus-open'),
                        tooltip: 'Open the Spatial Nexus',
                        onPressed: graph.nodes.isEmpty
                            ? null
                            : () => _showSpatialNexus(context, graph),
                        icon: const Icon(Icons.view_in_ar_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 8,
            top: 96,
            child: ActionChip(
              key: const Key('life_dashboard_open'),
              avatar: const Icon(Icons.space_dashboard_outlined, size: 18),
              label: Text(l10n.memoryGraphLifeDashboard),
              onPressed: () => _showLifeDashboard(context, graph),
            ),
          ),
          if (hasSampleGraphAction)
            Positioned(
              left: 8,
              top: sampleGraphTop,
              child: ActionChip(
                key: const Key('sample_graph_overlay_toggle'),
                avatar: Icon(
                  _showSample ? Icons.close : Icons.visibility_outlined,
                ),
                label: Text(
                  _showSample
                      ? l10n.memoryGraphClosePreview
                      : l10n.memoryGraphPreview,
                ),
                onPressed: () => setState(() => _showSample = !_showSample),
              ),
            ),
          if (_showSample)
            Positioned(
              top: sampleBadgeTop,
              left: 16,
              child: Chip(
                key: const Key('sample_graph_overlay_badge'),
                avatar: const Icon(Icons.science_outlined),
                label: Text(l10n.memoryGraphSampleBadge),
              ),
            ),
        ],
        if (spark != null && widget.onSparkSelected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: _showTimeMachine && hasTimeRange ? 112 : 12,
            child: SparkCard(
              spark: spark,
              onSelected: (selected) {
                setState(() {
                  _highlightedNodeIds = widget.graph.nodes
                      .where(
                        (node) => selected.relatedSeedLabels.any(
                          (label) =>
                              node.label.toLowerCase() == label.toLowerCase(),
                        ),
                      )
                      .map((node) => node.id)
                      .toSet();
                });
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => widget.onSparkSelected?.call(selected),
                );
              },
            ),
          ),
        if (_showTimeMachine && hasTimeRange)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: CanvasTimeMachineSlider(
              start: dates.first,
              end: dates.last,
              selected: _timeCutoff ?? dates.last,
              markers: markers,
              onChanged: _selectHistoricalTime,
            ),
          ),
        if (isHistorical)
          Positioned(
            right: 16,
            bottom: _showTimeMachine ? 112 : 16,
            child: FloatingActionButton.extended(
              key: const Key('canvas-return-to-present-fab'),
              heroTag: 'canvas-return-to-present',
              onPressed: _returnToPresent,
              icon: const Icon(Icons.update),
              label: Text(l10n.memoryGraphReturnToPresent),
            ),
          ),
        if (widget.showFirstEntryBurst)
          const Positioned(
            left: 12,
            right: 12,
            top: 104,
            child: InstantGraphBurst(),
          ),
        if (_showLifeSimulator && simulatorTarget != null) ...[
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                key: Key('life_simulator_canvas_dimmer'),
                color: Color(0x66000000),
              ),
            ),
          ),
          Positioned.fill(
            child: LifeSimulatorOverlay(
              target: simulatorTarget,
              load: (target, alternativePath) =>
                  _loadLifeSimulation(graph, target, alternativePath),
              hallucinationGuard: AppServices.isInitialized
                  ? HallucinationGuardService(
                      loadEntry: AppServices.instance.journalStore.getById,
                    )
                  : null,
              onClose: () => setState(() => _showLifeSimulator = false),
              onHighlightNodes: (nodeIds) {
                setState(() {
                  _highlightedNodeIds = nodeIds;
                  _showLifeSimulator = false;
                });
              },
              onBuildSmallSteps:
                  widget.onGenerateActionPlanFromTrajectory == null &&
                      !AppServices.isInitialized
                  ? null
                  : (trajectory) async {
                      final callback =
                          widget.onGenerateActionPlanFromTrajectory;
                      if (callback != null) {
                        await callback(trajectory);
                      } else {
                        final services = AppServices.instance;
                        final plan = await services.actionPlanGeneratorService
                            .generateFromTrajectory(trajectory, graph);
                        await services.actionPlanEngine.create(plan);
                      }
                      if (!mounted) return;
                      setState(() => _showLifeSimulator = false);
                      await _showActionPlans(this.context);
                    },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showOverview(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) {
          final counts = <NodeType, int>{};
          for (final node in _displayedGraph.nodes) {
            counts.update(node.type, (value) => value + 1, ifAbsent: () => 1);
          }
          final ranked = counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            key: const Key('memory_graph_overview_sheet'),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            shrinkWrap: true,
            children: [
              Text(
                'Your graph at a glance',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${_displayedGraph.nodes.length} nodes, '
                '${_displayedGraph.edges.length} connections, '
                '${widget.entries.length} saved memories',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in ranked)
                    Chip(label: Text('${_label(entry.key)} ${entry.value}')),
                ],
              ),
            ],
          );
        },
      );

  Future<void> _showLifeDashboard(
    BuildContext context,
    PersonalKnowledgeGraph graph,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .38),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .92,
      child: LifeDashboardOverlay(
        load:
            widget.dashboardLoader ??
            (horizon) {
              if (!AppServices.isInitialized) {
                throw StateError('App services are not initialized.');
              }
              final services = AppServices.instance;
              final engine = DashboardAggregationEngine(
                graph: graph,
                semanticStore: services.localSemanticStore,
              );
              final userId = services.auth.currentSession?.userId;
              return engine.aggregate(
                horizon,
                refreshSynthesis: userId == null
                    ? null
                    : (selected) =>
                          DashboardSynthesisService(
                            router: services.hybridAiRouter,
                            api: services.journalSyncApi,
                          ).synthesize(
                            horizon: selected,
                            userId: userId,
                            localMetrics: {
                              'nodeCount': graph.nodes.length,
                              'edgeCount': graph.edges.length,
                              'entryCount': widget.entries.length,
                            },
                            evidence: [
                              for (final entry in widget.entries)
                                if (ComparableEvidenceText.userText(
                                  entry,
                                ).trim().isNotEmpty)
                                  {
                                    'sourceEntryId': entry.id,
                                    'occurredAt': entry.createdAt
                                        .toUtc()
                                        .toIso8601String(),
                                    'canonicalTranscript':
                                        ComparableEvidenceText.userText(entry),
                                  },
                            ],
                            isOnline: true,
                          ),
              );
            },
        onHighlightNodes: (nodeIds) {
          setState(() => _highlightedNodeIds = nodeIds);
          Navigator.of(sheetContext).pop();
        },
      ),
    ),
  );

  Future<void> _showWeeklyIntelligence(
    BuildContext context,
    PersonalKnowledgeGraph graph,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .42),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .92,
      child: WeeklyIntelligenceSheet(
        load:
            widget.weeklyIntelligenceLoader ??
            () async {
              if (!AppServices.isInitialized) {
                throw StateError('App services are not initialized.');
              }
              final services = AppServices.instance;
              final digest = SundayDigestService(
                prefs: services.prefs,
                backend: CheckInReminderService.backend,
                prefetch: () async {
                  final local = await WeeklyDeltaEngine(
                    graph: graph,
                    semanticStore: services.localSemanticStore,
                  ).aggregate();
                  final userId = services.auth.currentSession?.userId;
                  if (userId == null) return local;
                  return await WeeklyIntelligenceSynthesisService(
                        router: services.hybridAiRouter,
                        api: services.journalSyncApi,
                      ).synthesize(
                        userId: userId,
                        local: local,
                        entries: widget.entries,
                        isOnline: true,
                      ) ??
                      local;
                },
              );
              final cached = await digest.loadCached();
              if (cached != null) {
                unawaited(digest.prefetchIfDue());
                return cached;
              }
              return await digest.prefetchIfDue() ??
                  WeeklyDeltaEngine(
                    graph: graph,
                    semanticStore: services.localSemanticStore,
                  ).aggregate();
            },
        onHighlightNodes: (nodeIds) {
          setState(() => _highlightedNodeIds = nodeIds);
          Navigator.of(sheetContext).pop();
        },
      ),
    ),
  );

  static String _label(NodeType type) => switch (type) {
    NodeType.journalEntry => 'Memories',
    NodeType.identityShift => 'Identity shifts',
    NodeType.archiveInsight => 'Insights',
    NodeType.chapter => 'Chapters',
    _ => '${type.name[0].toUpperCase()}${type.name.substring(1)}',
  };
}

GlassRenderQuality _graphGlassQuality(GlassEffectPreference preference) =>
    switch (preference) {
      GlassEffectPreference.automatic ||
      GlassEffectPreference.full => GlassRenderQuality.full,
      GlassEffectPreference.reduced => GlassRenderQuality.reduced,
      GlassEffectPreference.off => GlassRenderQuality.off,
    };

class InstantGraphBurst extends StatelessWidget {
  const InstantGraphBurst({super.key});

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('instant_graph_burst_banner'),
    elevation: 6,
    borderRadius: BorderRadius.circular(14),
    color: Theme.of(context).colorScheme.primaryContainer,
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Text(
        'Your Memory Graph is alive. 1 entry connected to 3 seed topics.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
