import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../design/empty_archive_experience.dart';
import '../features/archive_search/archive_entry_search_engine.dart';
import '../features/archive_search/archive_search_filters.dart';
import '../features/archive_search/archive_search_query.dart';
import '../features/archive_search/archive_search_result.dart';
import '../billing/archive_entitlement_reader.dart';
import '../billing/paywall_route_args.dart';
import '../billing/paywall_source.dart';
import '../features/bulk_actions/archive_selection_controller.dart';
import '../features/bulk_actions/bulk_archive_action.dart';
import '../features/archive_packs/archive_pack.dart';
import '../features/archive_packs/archive_pack_store.dart';
import '../features/action_items/action_item_filter.dart';
import '../features/action_items/action_item_store.dart';
import '../features/fact_ledger/fact_ledger_filter.dart';
import '../features/fact_ledger/fact_ledger_store.dart';
import '../features/collections/archive_collection.dart';
import '../features/collections/archive_collection_store.dart';
import '../features/memory/archive_thread.dart';
import '../features/memory/archive_thread_store.dart';
import '../features/onboarding/record_return_pro_state.dart';
import '../features/onboarding/record_return_pro_store.dart';
import '../features/activation/paywall_timing_gates.dart';
import '../features/retention/repeat_recording_nudge_state.dart';
import '../features/retention/repeat_recording_nudge_store.dart';
import '../features/aha/aha_moment_candidate.dart';
import '../features/aha/aha_moment_engine.dart';
import '../features/aha/aha_moment_store.dart';
import '../widgets/aha/first_aha_moment_card.dart';
import '../features/pins/pinned_evidence_store.dart';
import '../features/pressure_retention/pressure_check_in_record.dart';
import '../features/pressure_retention/pressure_check_in_store.dart';
import '../features/timeline/timeline_entry_display.dart';
import '../features/transcription_queue/transcription_job.dart';
import '../features/transcription_queue/transcription_timeline_snapshot.dart';
import '../models/journal_entry.dart';
import '../services/activation_funnel_analytics.dart';
import '../services/app_services.dart';
import '../services/app_services_providers.dart';
import '../security/private_data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/archive_search/archive_filter_chips.dart';
import '../widgets/archive_search/archive_search_bar.dart';
import '../widgets/archive_search/archive_search_result_card.dart';
import '../widgets/bulk_actions/archive_selection_bar.dart';
import '../widgets/bulk_actions/bulk_actions_flow.dart';
import '../widgets/collections/add_to_collection_sheet.dart';
import '../widgets/onboarding/first_archive_value_card.dart';
import '../widgets/trust/pro_value_clarity_card.dart';
import '../widgets/share/aha_proof_share_card.dart';
import '../features/trust/aha_proof_share_eligibility.dart';
import '../widgets/retention/second_entry_nudge_card.dart';
import '../widgets/retention/tiny_record_again_cta.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/timeline_sync_badge.dart';
import '../widgets/transcription_processing_card.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  static const _engine = ArchiveEntrySearchEngine();

  var _loading = true;
  List<JournalEntry> _entries = const [];
  List<TranscriptionJob> _pendingJobs = const [];
  ProviderSubscription<AsyncValue<TranscriptionTimelineSnapshot>>?
  _timelineSubscription;
  List<PressureCheckInRecord> _records = const [];
  List<ArchiveCollection> _collections = const [];
  List<ArchiveThread> _threads = const [];
  List<ArchivePack> _packs = const [];
  Set<String> _entryIdsWithActionItems = const {};
  Set<String> _entryIdsWithSavedDetails = const {};

  /// Search state lives only here — the query is never logged,
  /// persisted, or sent to analytics.
  var _query = const ArchiveEntrySearchQuery();

  final _selection = ArchiveSelectionController();

  /// Lets the first-archive helper focus the existing search input.
  final _searchFocus = FocusNode();

  final _searchController = TextEditingController();
  final _listScroll = ScrollController();

  /// Record → Return → Pro loop progress — gates the archive Pro bridge.
  RecordReturnProState? _recordReturnProState;
  bool _isPro = false;
  AhaMomentCandidate? _ahaCandidate;

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _selection.dispose();
    _searchFocus.dispose();
    _listScroll.dispose();
    _timelineSubscription?.close();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final text = _searchController.text;
    if (text == _query.keyword) return;
    _updateQuery(_query.copyWith(keyword: text));
  }

  void _updateQuery(ArchiveEntrySearchQuery next) {
    final wasSearching = !_query.isEmpty;
    final nowSearching = !next.isEmpty;
    setState(() => _query = next);
    if (!wasSearching && nowSearching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_listScroll.hasClients) {
          _listScroll.jumpTo(0);
        }
      });
    }
  }

  void _startSelectMode() {
    _selection.start();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveSelectModeStarted,
      source: 'archive_search',
    );
    setState(() {});
  }

  Future<void> _runBulkActions() async {
    await runBulkActionsFlow(
      context,
      controller: _selection,
      source: 'archive_search',
      allEntries: _entries,
      records: _records,
    );
    if (mounted) await _load();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    final peek = peekJournalEntriesSync(AppServices.instance.journalStore);
    if (isIntentionalEmptyArchive(peek)) {
      _entries = peek;
      _loading = false;
    }
    _load();
    _timelineSubscription = ref.listenManual(transcriptionTimelineProvider, (
      _,
      next,
    ) {
      next.whenData((snapshot) {
        if (!mounted) return;
        setState(() {
          _entries = snapshot.entries;
          _pendingJobs = snapshot.pendingJobs;
          _loading = false;
        });
      });
    }, fireImmediately: true);
  }

  Future<void> _load() async {
    final entries = await AppServices.instance.journalStore.loadAll();
    final records = await PressureCheckInStore.instance().loadAll();
    final collections = await ArchiveCollectionStore.instance().loadAll();
    final threads = await ArchiveThreadStore.instance().loadAll();
    final packs = await ArchivePackStore.instance().loadAll();
    final actionItems = await ActionItemStore.instance().loadAll();
    final facts = await FactLedgerStore.instance().loadAll();
    final loopState = await RecordReturnProStore.instance().load();
    final isPro = await ArchiveEntitlementReader.forAccessCheck().isPro;
    await AhaMomentStore.ensureLoaded();
    if (!mounted) return;
    final activeCount = entries.where((e) => !e.isArchived).length;
    setState(() {
      _entries = entries;
      _records = records;
      _collections = collections;
      _threads = threads;
      _packs = packs;
      _entryIdsWithActionItems = ActionItemFilter.entryIdsWithActionItems(
        actionItems,
      );
      _entryIdsWithSavedDetails = FactLedgerFilter.entryIdsWithFacts(facts);
      _recordReturnProState = loopState;
      _isPro = isPro;
      _loading = false;
      _ahaCandidate = const AhaMomentEngine().evaluate(
        records: records,
        entryCount: activeCount,
        hasStrongerMemoryCardVisible: false,
        source: 'archive',
        trackAnalytics: false,
      );
    });
  }

  /// Pins the single first entry through the existing pin flow.
  Future<void> _pinFirstEntry(JournalEntry entry) async {
    await PinnedEvidenceStore.instance().setPinned(entry.id, true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(PinnedEvidenceCopy.pinnedReceipt)),
    );
    await _load();
  }

  /// Resolves the first-60 Pro bridge once, then optionally opens the
  /// existing paywall.
  Future<void> _resolveFirstSaveProBridge({required bool seePro}) async {
    await RecordReturnProStore.instance().markProBridgeResolved();
    if (!mounted) return;
    setState(() {
      _recordReturnProState = _recordReturnProState?.copyWith(
        proBridgeResolved: true,
      );
    });
    if (seePro) {
      context.push(
        '/subscription',
        extra: PaywallRouteArgs(
          source: PaywallSource.valueMoment,
          sourceRoute: '/journal',
        ),
      );
    }
  }

  Future<void> _addToCollection(String entryId) async {
    await showAddToCollectionSheet(
      context,
      store: ArchiveCollectionStore.instance(),
      entryId: entryId,
      source: 'archive_search',
    );
    if (mounted) await _load();
  }

  void _openResult(ArchiveEntrySearchResult result, int resultCount) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.archiveSearchResultOpened,
      resultCountBucket: ActivationFunnelAnalytics.resultCountBucket(
        resultCount,
      ),
      source: 'journal',
    );
    context.go('/entry/${result.entry.id}');
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Archive',
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh archive list',
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty && _pendingJobs.isEmpty
          ? CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: IntentionalEmptyArchiveView(fillViewport: false),
                ),
              ],
            )
          : _archiveList(context),
    );
  }

  Widget _archiveList(BuildContext context) {
    final searching = !_query.isEmpty;
    final activeEntries = _entries.where((e) => !e.isArchived).toList();
    // First 60 Seconds: exactly one entry gets the small "archive has
    // started" helper (search / pin / return tomorrow) and, until answered
    // once, the soft Pro bridge. No Collections or bulk actions here —
    // those stay where they already live.
    final showArchiveValue =
        !searching &&
        !_selection.selecting &&
        FirstArchiveValueCard.shouldShow(activeEntries.length);
    final showProBridge =
        !searching &&
        !_selection.selecting &&
        _recordReturnProState != null &&
        RecordReturnProGates.showProBridge(
          entryCount: activeEntries.length,
          resolved: _recordReturnProState!.proBridgeResolved,
          isPro: _isPro,
          hasArchiveProof: PaywallTimingGates.hasArchiveProofFromEntries(
            entries: activeEntries,
          ),
        );
    final showSecondEntryNudge =
        !searching &&
        !_selection.selecting &&
        RepeatRecordingNudgeGates.showSecondEntryNudge(
          entryCount: activeEntries.length,
          justSaved: false,
          hiddenThisSession: RepeatRecordingNudgeSession.secondEntryHidden,
        );
    final showRecordAgainCta =
        !searching &&
        !_selection.selecting &&
        RepeatRecordingNudgeGates.showRecordAgainOnArchive(
          entryCount: activeEntries.length,
          showingFirstArchiveValueCard: showArchiveValue,
        );
    final showAhaMoment =
        !searching &&
        !_selection.selecting &&
        AhaMomentGates.shouldShow(
          candidate: _ahaCandidate,
          entryCount: activeEntries.length,
        );
    final results = searching
        ? _engine.search(
            entries: _entries,
            records: _records,
            collections: _collections,
            threads: _threads,
            packs: _packs,
            query: _query,
            entryIdsWithActionItems: _entryIdsWithActionItems,
            entryIdsWithSavedDetails: _entryIdsWithSavedDetails,
          )
        : const <ArchiveEntrySearchResult>[];
    final visibleIds = searching
        ? [for (final r in results) r.entry.id]
        : [
            for (final e in _entries)
              if (!e.isArchived) e.id,
          ];

    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => ListView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
        controller: _listScroll,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (!searching && !_selection.selecting)
            for (final job in _pendingJobs)
              TranscriptionProcessingCard(
                job: job,
                onUseTypedText: () => context.push(
                  '/quick-capture',
                  extra: {'queueJobId': job.id},
                ),
              ),
          if (showArchiveValue) ...[
            FirstArchiveValueCard(
              onSearch: _searchFocus.requestFocus,
              onRecordAnother: () => context.go('/record'),
              onPin: activeEntries.first.isPinned
                  ? null
                  : () => _pinFirstEntry(activeEntries.first),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (showProBridge) ...[
            ProValueClarityCard(
              entryCount: activeEntries.length,
              source: 'archive',
              onSeePro: () => _resolveFirstSaveProBridge(seePro: true),
              onNotNow: () => _resolveFirstSaveProBridge(seePro: false),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (showSecondEntryNudge) ...[
            SecondEntryNudgeCard(
              source: 'archive',
              onRecord: () => context.go('/record'),
              onDismiss: () => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (showAhaMoment) ...[
            FirstAhaMomentCard(
              candidate: _ahaCandidate!,
              source: 'archive',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (AhaProofShareEligibility.shouldShow) ...[
            AhaProofShareCard(
              entryCount: activeEntries.length,
              source: 'archive',
              onDismiss: () => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          ArchiveSearchBar(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: (text) => _updateQuery(_query.copyWith(keyword: text)),
          ),
          if (searching && results.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _emptySearchState(context),
          ],
          const SizedBox(height: AppSpacing.xs),
          ArchiveFilterChips(
            query: _query,
            availableContextTags: _engine.availableContextTags(_records),
            availableCollections: _collections,
            availableThreads: _engine.availableThreads(_entries, _threads),
            availablePacks: _engine.availablePacks(_entries, _packs),
            onChanged: (next) => _updateQuery(next),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_selection.selecting)
            ArchiveSelectionBar(
              controller: _selection,
              allIds: visibleIds,
              onActions: _runBulkActions,
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('journal_select_button'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _startSelectMode,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(BulkActionsCopy.select),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          if (!searching)
            ..._plainEntries(context)
          else if (results.isNotEmpty)
            for (final result in results) ...[
              _selectableRow(
                entryId: result.entry.id,
                child: ArchiveSearchResultCard(
                  result: result,
                  onTap: _selection.selecting
                      ? () => _selection.toggle(result.entry.id)
                      : () => _openResult(result, results.length),
                  onAddToCollection: _selection.selecting
                      ? null
                      : () => _addToCollection(result.entry.id),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          if (showRecordAgainCta) ...[
            TinyRecordAgainCta(
              entryCount: activeEntries.length,
              source: 'archive',
              onRecord: () => context.go('/record'),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  /// Adds a selection checkbox in select mode; passes through otherwise.
  Widget _selectableRow({required String entryId, required Widget child}) {
    if (!_selection.selecting) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          key: Key('select_entry_$entryId'),
          value: _selection.isSelected(entryId),
          onChanged: (_) => _selection.toggle(entryId),
        ),
        Expanded(child: child),
      ],
    );
  }

  List<Widget> _plainEntries(BuildContext context) {
    // Archived entries are hidden from the default list; the Archived
    // filter in search reveals them.
    final visible = _entries.where((e) => !e.isArchived).toList();
    return [
      for (final e in visible)
        _selectableRow(
          entryId: e.id,
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        timelineEntryTitle(e),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (timelineSyncBadgeLabel(e.syncStatus) != null) ...[
                      const SizedBox(width: 8),
                      TimelineSyncBadge(
                        label: timelineSyncBadgeLabel(e.syncStatus)!,
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${e.createdAt.toLocal()} · ${e.durationSeconds}s',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                onTap: _selection.selecting
                    ? () => _selection.toggle(e.id)
                    : () => context.go('/entry/${e.id}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete local entry',
                  onPressed: () async {
                    await PrivateDataService(
                      journalStore: AppServices.instance.journalStore,
                      audioVault: AppServices.instance.journalAudioVault,
                    ).deleteEntrySecurely(e.id);
                    if (context.mounted) _load();
                  },
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
    ];
  }

  Widget _emptySearchState(BuildContext context) {
    return Padding(
      key: const Key('archive_search_empty_state'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Text(
            ArchiveSearchCopy.emptyTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveSearchCopy.emptyHelper,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
