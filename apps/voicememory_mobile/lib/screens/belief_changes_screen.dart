import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../features/changes/change_correction_admission.dart';
import '../features/changes/change_customer_presentation.dart';
import '../features/changes/change_date_format.dart';
import '../features/changes/change_evidence_navigation.dart';
import '../features/changes/change_evidence_visibility.dart';
import '../features/changes/change_resurfacing.dart';
import '../features/changes/change_review_history.dart';
import '../features/changes/change_structured_markers.dart';
import '../features/changes/change_thread.dart';
import '../features/changes/change_thread_correction.dart';
import '../features/changes/change_thread_identity.dart';
import '../features/changes/change_thread_projection.dart';
import '../features/changes/change_thread_repository.dart';
import '../features/changes/changes_analytics.dart';
import '../features/explainable_conclusion/change_dimensions.dart';
import '../features/explainable_conclusion/explainable_conclusion.dart';
import '../features/insight_feedback/insight_feedback_store.dart';
import '../features/weekly_review/weekly_review.dart';
import '../features/weekly_review/weekly_review_entry_card.dart';
import '../features/weekly_review/weekly_review_repository.dart';
import '../features/weekly_review/weekly_review_screen.dart';
import '../models/journal_entry.dart';
import '../models/reflection.dart';
import '../product/consumer_ui_copy.dart';
import '../router/primary_destination.dart';
import '../router/primary_navigation_controller.dart';
import '../services/evidence_receipt_analytics.dart';
import '../services/focused_return_analytics.dart';
import '../theme/app_spacing.dart';
import '../widgets/accessibility/accessible_primary_surface.dart';

export '../features/changes/change_date_format.dart'
    show formatDateRange, formatFullDate;

/// The one line shown when there is nothing to compare. Returning, not
/// reading, is what gives ArchiveMe something to work with.
const changesEmptyStateCopy =
    'Record a real moment. Returning gives ArchiveMe something to compare.';

/// Changes — the third primary destination.
///
/// The default view is deliberately compact: one row per thread, so a
/// recurring issue reads as one continuing line rather than a stack of long
/// unrelated cards. Everything that justifies a row — the exact quotes, the
/// dates, the dimensions that moved, the uncertainty — lives one tap away in
/// the thread's own history.
///
/// The weekly review appears here as a single card, never as a fifth tab: it
/// is an entry point into these threads, not a separate product.
class BeliefChangesScreen extends StatefulWidget {
  const BeliefChangesScreen({
    super.key,
    this.previewReliableChange,
    this.previewConclusions,
    this.previewTranscripts = const {},
    this.previewHasHistory = false,
  });

  @visibleForTesting
  final ExplainableConclusion? previewReliableChange;

  @visibleForTesting
  final List<ExplainableConclusion>? previewConclusions;

  @visibleForTesting
  final Map<String, String> previewTranscripts;

  @visibleForTesting
  final bool previewHasHistory;

  @override
  State<BeliefChangesScreen> createState() => _BeliefChangesScreenState();
}

class _BeliefChangesScreenState extends State<BeliefChangesScreen> {
  ChangesSnapshot _snapshot = ChangesSnapshot.empty();
  WeeklyReviewSnapshot _weekly = const WeeklyReviewSnapshot.none();
  bool _hasMoments = false;
  bool _loading = true;

  ChangeThreadProjection get _projection => _snapshot.projection;

  bool get _isPreview =>
      widget.previewReliableChange != null ||
      widget.previewConclusions != null ||
      widget.previewHasHistory;

  @override
  void initState() {
    super.initState();
    if (_isPreview) {
      _loadPreview();
      return;
    }
    primaryNavigationController.addListener(_handlePrimaryActivation);
    _load();
  }

  @override
  void dispose() {
    primaryNavigationController.removeListener(_handlePrimaryActivation);
    super.dispose();
  }

  void _handlePrimaryActivation() {
    if (!mounted ||
        _loading ||
        _isPreview ||
        primaryNavigationController.activeDestination !=
            PrimaryDestination.changes) {
      return;
    }
    _load();
  }

  void _loadPreview() {
    final conclusions = [
      ...?widget.previewConclusions,
      ?widget.previewReliableChange,
    ];
    final entries = _previewEntries(conclusions);
    _hasMoments = entries.isNotEmpty;
    _snapshot = ChangesSnapshot(
      projection: ChangeThreadProjector.project(
        archiveId: 'local',
        entries: entries,
        conclusions: conclusions,
        feedback: InsightFeedbackStore.cached,
      ),
      resurfacing: ChangeResurfacingContext.fromEntries(
        entries,
        now: DateTime.now().toUtc(),
      ),
      corrections: const [],
      entries: entries,
    );
    _loading = false;
    _reportViewed();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snapshot = await ChangeThreadRepository.load();
    final weekly = await WeeklyReviewRepository.load(snapshot);
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _weekly = weekly;
      _hasMoments = snapshot.hasMoments;
      _loading = false;
    });
    _reportViewed();
  }

  void _reportViewed() {
    // Preview fixtures are test/demo data and must never enter product
    // analytics as if they were a customer's archive.
    if (_isPreview) return;
    final changed = _projection.threads
        .where((view) => _isChange(view.thread.currentStatus))
        .toList(growable: false);
    if (changed.isNotEmpty) {
      unawaited(
        EvidenceReceiptAnalytics.reliableChangeDisplayed(
          evidenceCount: changed.last.savedMomentCount,
        ),
      );
    }
    unawaited(
      FocusedReturnAnalytics.changesViewed(
        hasReliableChange: changed.isNotEmpty,
      ),
    );
    unawaited(ChangesAnalytics.record(ChangesAnalyticsEvent.changesOpened));
  }

  static bool _isChange(ChangeThreadStatus status) =>
      status == ChangeThreadStatus.changed ||
      status == ChangeThreadStatus.weakened ||
      status == ChangeThreadStatus.strengthened;

  List<JournalEntry> _previewEntries(List<ExplainableConclusion> conclusions) {
    final citations = <String, TranscriptEvidenceCitation>{};
    for (final conclusion in conclusions) {
      for (final citation in conclusion.evidence) {
        citations.putIfAbsent(citation.entryId, () => citation);
      }
    }
    return [
      for (final MapEntry(key: id, value: citation) in citations.entries)
        JournalEntry(
          id: id,
          createdAt:
              citation.sourceCapturedAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          transcript: widget.previewTranscripts[id] ?? citation.quote,
          durationSeconds: 0,
          source: citation.sourceType == EvidenceSourceType.voice
              ? SavedMomentSource.voice
              : SavedMomentSource.typed,
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 0,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        ),
    ];
  }

  List<Widget> _pageHeader(BuildContext context) {
    final theme = Theme.of(context);
    return [
      Semantics(
        header: true,
        child: Text(
          ConsumerUiCopy.changesScreenTitle,
          style: theme.textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        ConsumerUiCopy.changesScreenLead,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  void _openThread(ChangeThreadView view) {
    unawaited(
      ChangesAnalytics.record(ChangesAnalyticsEvent.changeThreadOpened),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeThreadDetailScreen(
          view: view,
          resurfacing: ChangeResurfacingPolicy.noteFor(
            view,
            context: _snapshot.resurfacing,
          ),
          reviewHistory: ChangeReviewHistory.forThread(
            view.thread.threadId,
            _snapshot.corrections,
          ),
          availableThreads: _projection.threads,
          onCorrection: _isPreview ? null : _applyCorrection,
        ),
      ),
    );
  }

  void _openWeeklyReview(WeeklyReview review) {
    unawaited(
      ChangesAnalytics.record(ChangesAnalyticsEvent.weeklyReviewOpened),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyReviewScreen(
          review: review,
          onOpenThread: (threadId) {
            final view = _projection.byId(threadId);
            if (view == null) return;
            Navigator.of(context).pop();
            _openThread(view);
          },
          onOpenMoment: (citation) => context.push(evidenceRouteFor(citation)),
        ),
      ),
    );
  }

  Future<void> _applyCorrection(ChangeThreadCorrection correction) async {
    final snapshot = await ChangeThreadRepository.correctAndLoad(correction);
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _primarySurface(
        const Scaffold(
          body: SafeArea(
            child: Padding(
              padding: ArchiveMobileSpacing.pagePadding,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }

    final threads = _projection.threads;
    final ungrouped = _projection.ungroupedEvents;
    final resurfacing = _snapshot.resurfacing;

    if (!_hasMoments && threads.isEmpty && ungrouped.isEmpty) {
      return _primarySurface(
        Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _isPreview ? () async {} : _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: ArchiveMobileSpacing.pagePadding,
                children: [
                  ..._pageHeader(context),
                  const _EmptyCard(key: Key('changes_empty_state')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final review = _weekly.review;

    return _primarySurface(
      Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _isPreview ? () async {} : _load,
            child: ListView(
              padding: ArchiveMobileSpacing.pagePadding,
              children: [
                ..._pageHeader(context),
                if (review != null) ...[
                  WeeklyReviewEntryCard(
                    review: review,
                    onOpen: () => _openWeeklyReview(review),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (threads.isNotEmpty) ...[
                  Text(
                    _summaryLine(threads),
                    key: const Key('changes_restrained_summary'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final view in threads) ...[
                    ChangeThreadSummaryCard(
                      key: ValueKey('change_thread_${view.thread.threadId}'),
                      view: view,
                      excerpt: ChangeEvidenceVisibility.safeExcerpt(
                        view,
                        context: resurfacing,
                      ),
                      resurfacing: ChangeResurfacingPolicy.noteFor(
                        view,
                        context: resurfacing,
                      ),
                      onOpen: () => _openThread(view),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ] else
                  const _EmptyCard(key: Key('changes_insufficient_history')),
                if (ungrouped.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Not grouped yet',
                    key: const Key('changes_ungrouped_heading'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'These moments could belong to more than one thread, so '
                    'ArchiveMe left them on their own.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final event in ungrouped) ...[
                    _UngroupedEventTile(
                      key: ValueKey('change_ungrouped_${event.eventId}'),
                      event: event,
                      quote:
                          ChangeEvidenceVisibility.mayQuoteUnasked(
                            event.nowEvidence,
                            context: resurfacing,
                          )
                          ? event.nowEvidence.quote
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primarySurface(Widget child) =>
      AccessiblePrimarySurface(label: 'Changes screen', child: child);

  static String _summaryLine(List<ChangeThreadView> threads) {
    final changes = threads
        .where((view) => _isChange(view.thread.currentStatus))
        .length;
    final repeats = threads
        .where(
          (view) => view.thread.currentStatus == ChangeThreadStatus.repeated,
        )
        .length;
    final latest = threads
        .map((view) => view.thread.latestObservedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return '$changes possible ${changes == 1 ? 'change' : 'changes'} · '
        '$repeats repeated ${repeats == 1 ? 'moment' : 'moments'} · '
        'latest evidence ${formatFullDate(latest)}';
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            changesEmptyStateCopy,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('changes_record_a_moment'),
            onPressed: () => context.go('/record'),
            icon: const Icon(Icons.mic_none),
            label: const Text('Record a moment'),
          ),
        ],
      ),
    ),
  );
}

/// The compact default row for one thread.
class ChangeThreadSummaryCard extends StatelessWidget {
  const ChangeThreadSummaryCard({
    super.key,
    required this.view,
    required this.onOpen,
    this.excerpt,
    this.resurfacing,
  });

  final ChangeThreadView view;
  final VoidCallback onOpen;

  /// The strongest quote this row may carry, or null when the row must not
  /// quote the moment unasked.
  final String? excerpt;

  /// The one short line explaining why this thread is worth looking at again.
  final ChangeResurfacingNote? resurfacing;

  /// Everything the row says, in the order it should be announced.
  String get accessibilityLabel {
    final thread = view.thread;
    final presentation = ChangeCustomerPresentationMapper.forThread(thread);
    final moments = view.savedMomentCount;
    return [
      thread.userEditableLabel,
      presentation.primaryStatus,
      ?presentation.secondaryExplanation,
      '$moments saved ${moments == 1 ? 'moment' : 'moments'}',
      formatDateRange(thread.firstObservedAt, thread.latestObservedAt),
      if (excerpt != null) 'Strongest evidence: $excerpt',
      ?view.correctionMarker,
      ?resurfacing?.message,
    ].join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thread = view.thread;
    final presentation = ChangeCustomerPresentationMapper.forThread(thread);
    final moments = view.savedMomentCount;
    final correction = view.correctionMarker;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: accessibilityLabel,
      onTap: onOpen,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('change_thread_open_${thread.threadId}'),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.userEditableLabel,
                  key: ValueKey('change_thread_label_${thread.threadId}'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  presentation.primaryStatus,
                  key: ValueKey('change_thread_status_${thread.threadId}'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (presentation.secondaryExplanation != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    presentation.secondaryExplanation!,
                    key: ValueKey(
                      'change_thread_status_detail_${thread.threadId}',
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$moments saved ${moments == 1 ? 'moment' : 'moments'} · '
                  '${formatDateRange(thread.firstObservedAt, thread.latestObservedAt)}',
                  key: ValueKey('change_thread_meta_${thread.threadId}'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (excerpt != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '“$excerpt”',
                    key: ValueKey('change_thread_excerpt_${thread.threadId}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (correction != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    correction,
                    key: ValueKey(
                      'change_thread_correction_${thread.threadId}',
                    ),
                    style: theme.textTheme.labelMedium,
                  ),
                ],
                if (resurfacing != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    resurfacing!.message,
                    key: ValueKey(
                      'change_thread_resurfacing_${thread.threadId}',
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UngroupedEventTile extends StatelessWidget {
  const _UngroupedEventTile({super.key, required this.event, this.quote});

  final ChangeEvent event;
  final String? quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ChangeCustomerPresentationMapper.forStatus(
                ChangeThreadStatus.unresolved,
              ).primaryStatus,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatFullDate(event.occurredAt),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (quote != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('“$quote”', style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// One thread's full, chronological history.
class ChangeThreadDetailScreen extends StatelessWidget {
  const ChangeThreadDetailScreen({
    super.key,
    required this.view,
    this.onCorrection,
    this.resurfacing,
    this.reviewHistory = const [],
    this.structuredMarkers,
    this.availableThreads = const [],
  });

  final ChangeThreadView view;

  /// Applied when the user renames the thread or hides its framing. Null in
  /// preview, where there is no archive to write to.
  final Future<void> Function(ChangeThreadCorrection)? onCorrection;

  final ChangeResurfacingNote? resurfacing;

  /// What the user has already done to this thread, oldest first.
  final List<ChangeReviewEntry> reviewHistory;

  /// Optional marker store. When absent, this screen renders without markers
  /// rather than reserving space for something that may never arrive.
  final ChangeStructuredMarkerLookup? structuredMarkers;

  /// Current archive threads offered as merge destinations.
  final List<ChangeThreadView> availableThreads;

  List<ChangeStructuredMarker> get _markers {
    final lookup = structuredMarkers;
    if (lookup != null) return lookup(view.thread.threadId);
    return ChangeStructuredMarkers.forThread(view.thread.threadId);
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(
      text: view.thread.userEditableLabel,
    );
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename this thread'),
        content: TextField(
          key: const Key('change_thread_rename_field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'What is this about?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    await onCorrection?.call(
      RenameChangeThread(
        threadId: view.thread.threadId,
        label: label,
        at: DateTime.now().toUtc(),
      ),
    );
    if (context.mounted) Navigator.of(context).maybePop();
  }

  Future<void> _suppress(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hide this framing?'),
        content: const Text(
          'The saved moments stay in your archive. This reading will stop '
          'appearing in Changes, and the choice remains in its review history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('change_thread_hide_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hide framing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await onCorrection?.call(
      SuppressChangeThreadFraming(
        threadId: view.thread.threadId,
        at: DateTime.now().toUtc(),
      ),
    );
    if (context.mounted) Navigator.of(context).maybePop();
  }

  Future<void> _split(BuildContext context) async {
    if (view.events.length < 2) return;
    final selected = <String>{view.events.last.eventId};
    final labelController = TextEditingController();
    final eventIds = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Split this thread'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose the findings that should move into a separate '
                  'thread. Nothing is deleted.',
                ),
                for (final event in view.events)
                  CheckboxListTile(
                    key: ValueKey('change_split_event_${event.eventId}'),
                    value: selected.contains(event.eventId),
                    title: Text(formatFullDate(event.occurredAt)),
                    subtitle: Text('“${event.nowEvidence.quote}”'),
                    onChanged: (checked) => setDialogState(() {
                      if (checked == true) {
                        selected.add(event.eventId);
                      } else {
                        selected.remove(event.eventId);
                      }
                    }),
                  ),
                TextField(
                  key: const Key('change_split_label'),
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'New thread label (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('change_split_preview'),
              onPressed:
                  selected.isEmpty || selected.length == view.events.length
                  ? null
                  : () => Navigator.of(
                      dialogContext,
                    ).pop(Set<String>.from(selected)),
              child: const Text('Review split'),
            ),
          ],
        ),
      ),
    );
    if (eventIds == null || !context.mounted) {
      labelController.dispose();
      return;
    }
    final moved = view.events
        .where((event) => eventIds.contains(event.eventId))
        .toList(growable: false);
    final movedSubject = {
      for (final event in moved)
        ...ChangeDimensionReader.subjectMarkers(event.nowEvidence.quote),
    };
    final enteredLabel = labelController.text.trim();
    final resultingLabel = enteredLabel.isNotEmpty
        ? enteredLabel
        : ChangeThreadIdentity.labelFor(movedSubject, fallback: 'New thread');
    labelController.dispose();
    final confirmed = await _confirmCorrection(
      context,
      title: 'Apply this split?',
      resultLines: [
        'Keeps: ${view.thread.userEditableLabel}',
        'Creates: $resultingLabel',
      ],
      eventGroups: [
        ('Moving to $resultingLabel', moved),
        (
          'Staying in ${view.thread.userEditableLabel}',
          view.events
              .where((event) => !eventIds.contains(event.eventId))
              .toList(growable: false),
        ),
      ],
      confirmKey: const Key('change_split_confirm'),
      confirmLabel: 'Apply split',
    );
    if (!confirmed || !context.mounted) return;
    await onCorrection?.call(
      SplitChangeThread(
        threadId: view.thread.threadId,
        eventIds: eventIds,
        newLabel: enteredLabel.isEmpty ? null : enteredLabel,
        at: DateTime.now().toUtc(),
      ),
    );
    if (context.mounted) Navigator.of(context).maybePop();
  }

  Future<void> _merge(BuildContext context) async {
    final candidates = availableThreads
        .where((candidate) => candidate.thread.threadId != view.thread.threadId)
        .toList(growable: false);
    if (candidates.isEmpty) return;
    final into = await showDialog<ChangeThreadView>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Merge into which thread?'),
        children: [
          for (final candidate in candidates)
            SimpleDialogOption(
              key: ValueKey('change_merge_target_${candidate.thread.threadId}'),
              onPressed: () => Navigator.of(dialogContext).pop(candidate),
              child: Text(candidate.thread.userEditableLabel),
            ),
        ],
      ),
    );
    if (into == null || !context.mounted) return;
    final admission = ChangeCorrectionAdmission.merge(view.thread, into.thread);
    if (!admission.allowed) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('These threads cannot be merged'),
          content: Text(admission.refusalMessage!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    if (!context.mounted) return;
    final confirmed = await _confirmCorrection(
      context,
      title: 'Apply this merge?',
      resultLines: [
        'Combines: ${view.thread.userEditableLabel}',
        'With: ${into.thread.userEditableLabel}',
        'Result: ${admission.resultingLabel}',
      ],
      eventGroups: [
        (view.thread.userEditableLabel, view.events),
        (into.thread.userEditableLabel, into.events),
      ],
      confirmKey: const Key('change_merge_confirm'),
      confirmLabel: 'Apply merge',
    );
    if (!confirmed || !context.mounted) return;
    await onCorrection?.call(
      MergeChangeThreads(
        threadId: view.thread.threadId,
        intoThreadId: into.thread.threadId,
        at: DateTime.now().toUtc(),
      ),
    );
    if (context.mounted) Navigator.of(context).maybePop();
  }

  Future<bool> _confirmCorrection(
    BuildContext context, {
    required String title,
    required List<String> resultLines,
    required List<(String, List<ChangeEvent>)> eventGroups,
    required Key confirmKey,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in resultLines) Text(line),
                const SizedBox(height: AppSpacing.md),
                for (final group in eventGroups) ...[
                  Text(
                    group.$1,
                    style: Theme.of(dialogContext).textTheme.labelLarge,
                  ),
                  for (final event in group.$2) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text('Event · ${formatFullDate(event.occurredAt)}'),
                    for (final citation in event.exactEvidence)
                      Text(
                        '${citation.sourceCapturedAt == null ? 'Source date unavailable' : 'Source · ${formatFullDate(citation.sourceCapturedAt!)}'}\n'
                        '“${citation.quote}”',
                      ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
                const Text(
                  'Original findings and this action remain in review history.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: confirmKey,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thread = view.thread;
    final presentation = ChangeCustomerPresentationMapper.forThread(thread);
    final correction = view.correctionMarker;
    final markers = _markers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
        actions: [
          if (onCorrection != null)
            PopupMenuButton<void>(
              key: const Key('change_thread_corrections'),
              itemBuilder: (menuContext) => [
                PopupMenuItem<void>(
                  onTap: () => _rename(context),
                  child: const Text('Rename this thread'),
                ),
                if (view.events.length > 1)
                  PopupMenuItem<void>(
                    onTap: () => _split(context),
                    child: const Text('Split this thread'),
                  ),
                if (availableThreads.any(
                  (candidate) => candidate.thread.threadId != thread.threadId,
                ))
                  PopupMenuItem<void>(
                    onTap: () => _merge(context),
                    child: const Text('Merge with another thread'),
                  ),
                PopupMenuItem<void>(
                  onTap: () => _suppress(context),
                  child: const Text('Hide this framing'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: ArchiveMobileSpacing.pagePadding,
          children: [
            Semantics(
              header: true,
              child: Text(
                thread.userEditableLabel,
                key: const Key('change_thread_detail_label'),
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${presentation.primaryStatus} · '
              '${formatDateRange(thread.firstObservedAt, thread.latestObservedAt)}',
              key: const Key('change_thread_detail_meta'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (presentation.secondaryExplanation != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                presentation.secondaryExplanation!,
                key: const Key('change_thread_detail_status_explanation'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (correction != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                correction,
                key: const Key('change_thread_detail_correction'),
                style: theme.textTheme.labelMedium,
              ),
            ],
            if (resurfacing != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                resurfacing!.message,
                key: const Key('change_thread_detail_resurfacing'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (markers.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final marker in markers)
                Text(
                  '${marker.label}: ${marker.detail}',
                  key: ValueKey('change_thread_marker_${marker.label}'),
                  style: theme.textTheme.labelMedium,
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            for (final event in view.events) ...[
              _ChangeEventTile(event: event),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (reviewHistory.isNotEmpty) ...[
              Text(
                'What you changed here',
                key: const Key('change_thread_review_history'),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final entry in reviewHistory)
                Text(
                  '${formatFullDate(entry.at)} · ${entry.description}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeEventTile extends StatelessWidget {
  const _ChangeEventTile({required this.event});

  final ChangeEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final then = event.thenEvidence;
    final now = event.nowEvidence;
    final isComparison = !identical(then, now);
    final presentation = ChangeCustomerPresentationMapper.forEvent(event);
    final correction = presentation.correctionMarker;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              presentation.primaryStatus,
              key: ValueKey('change_event_status_${event.eventId}'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (presentation.secondaryExplanation != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                presentation.secondaryExplanation!,
                key: ValueKey('change_event_status_detail_${event.eventId}'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (event.statement.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(event.statement, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: AppSpacing.md),
            if (isComparison) ...[
              _EvidenceBlock(label: 'Then', citation: then),
              const SizedBox(height: AppSpacing.sm),
              _EvidenceBlock(label: 'Now', citation: now),
            ] else
              _EvidenceBlock(label: 'Saved', citation: now),
            if (event.contradictingEvidence.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final citation in event.contradictingEvidence) ...[
                _EvidenceBlock(
                  label: 'Contradicting evidence',
                  citation: citation,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
            if (event.changedDimensions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'What moved: '
                '${event.changedDimensions.map((dimension) => dimension.label).join(', ')}',
                key: ValueKey('change_event_dimensions_${event.eventId}'),
                style: theme.textTheme.labelMedium,
              ),
            ],
            if (event.uncertainty.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                event.uncertainty,
                key: ValueKey('change_event_uncertainty_${event.eventId}'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (event.alternativeExplanation.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'It could also be: ${event.alternativeExplanation}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (correction != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(correction, style: theme.textTheme.labelMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _EvidenceBlock extends StatelessWidget {
  const _EvidenceBlock({required this.label, required this.citation});

  final String label;
  final TranscriptEvidenceCitation citation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final capturedAt = citation.sourceCapturedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          capturedAt == null ? label : '$label · ${formatFullDate(capturedAt)}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('“${citation.quote}”', style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.push(evidenceRouteFor(citation)),
            child: const Text('Open exact moment'),
          ),
        ),
      ],
    );
  }
}
