import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../changes/change_thread.dart';
import '../changes/change_thread_projection.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../weekly_review/weekly_review.dart';
import 'archive_ownership_copy.dart';

/// What the export says about itself: counts, field list, and the promises the
/// archive is handed over under.
class ArchiveExportManifest {
  const ArchiveExportManifest({
    required this.archiveId,
    required this.entryCount,
    required this.activeEntryCount,
    required this.archivedEntryCount,
    required this.deletedEntryCount,
    required this.correctionCount,
    required this.evidenceLinkCount,
    required this.audioReferenceCount,
    required this.changeThreadCount,
    required this.changeEventCount,
    required this.unplacedChangeEventCount,
    required this.weeklyReviewCount,
  });

  static const String app = 'ArchiveMe';

  /// Bumped whenever the shape below changes in a way a reader must notice.
  static const int formatVersion = 3;

  static const String audioPolicy = 'bytes_excluded';

  static const String accessNote =
      'No subscription is required for any part of this export. Exporting your '
      'own moments is user-owned and is never metered or gated.';

  static const String audioNote =
      'Audio bytes are excluded from this readable export. Every entry carries '
      'an audio reference so it can be matched back to the vault object. After '
      'handoff, the destination you choose controls these plaintext files.';

  static const String determinismNote =
      'The same archive state always produces byte-identical output. Entries, '
      'corrections, evidence links, threads and events are sorted by stable '
      'keys, and no generation timestamp is embedded in either document.';

  static const String tombstoneNote =
      'Deleted moments are exported as tombstones carrying the state deleted '
      'and the time they were deleted, so a reader can tell a removed moment '
      'apart from one that was never captured.';

  /// Every field a reader can expect to find on an exported moment.
  static const List<String> entryFields = [
    'id',
    'ownerArchiveId',
    'source',
    'schemaVersion',
    'state',
    'syncStatus',
    'timestamps.createdAt',
    'timestamps.updatedAt',
    'timestamps.deletedAt',
    'timestamps.pinnedAt',
    'timestamps.archivedAt',
    'text.transcript',
    'text.earliestRetainedText',
    'text.durationSeconds',
    'corrections[].editedAt',
    'corrections[].source',
    'corrections[].text',
    'evidenceLinks[].startUtf16',
    'evidenceLinks[].endUtf16',
    'evidenceLinks[].audioStartMs',
    'evidenceLinks[].audioEndMs',
    'evidenceLinks[].quotedText',
    'audio.referenceKind',
    'audio.reference',
    'audio.bytesIncluded',
    'markers',
    'interpretation',
    'mediaReferences',
  ];

  /// Every field a reader can expect on the Changes history.
  static const List<String> changeFields = [
    'threads[].threadId',
    'threads[].label',
    'threads[].subjectRepresentation',
    'threads[].firstObservedAt',
    'threads[].latestObservedAt',
    'threads[].currentStatus',
    'threads[].correctionState',
    'threads[].visibilityState',
    'threads[].policyVersion',
    'threads[].events[].eventId',
    'threads[].events[].occurredAt',
    'threads[].events[].statement',
    'threads[].events[].status',
    'threads[].events[].conclusionKind',
    'threads[].events[].changedDimensions',
    'threads[].events[].confidenceBand',
    'threads[].events[].uncertainty',
    'threads[].events[].alternativeExplanation',
    'threads[].events[].correctionState',
    'threads[].events[].evidence[].entryId',
    'threads[].events[].evidence[].quote',
    'threads[].events[].evidence[].startUtf16',
    'threads[].events[].evidence[].endUtf16',
    'unplacedEvents[]',
  ];

  static const List<String> weeklyReviewFields = [
    'weeklyReviews[].reviewId',
    'weeklyReviews[].windowStart',
    'weeklyReviews[].windowEnd',
    'weeklyReviews[].generatedAt',
    'weeklyReviews[].policyVersion',
    'weeklyReviews[].items[].kind',
    'weeklyReviews[].items[].threadId',
    'weeklyReviews[].items[].threadLabel',
    'weeklyReviews[].items[].eventId',
    'weeklyReviews[].items[].statement',
    'weeklyReviews[].items[].evidence',
    'weeklyReviews[].items[].occurredAt',
  ];

  final String archiveId;
  final int entryCount;
  final int activeEntryCount;
  final int archivedEntryCount;
  final int deletedEntryCount;
  final int correctionCount;
  final int evidenceLinkCount;
  final int audioReferenceCount;
  final int changeThreadCount;
  final int changeEventCount;
  final int unplacedChangeEventCount;
  final int weeklyReviewCount;

  Map<String, Object?> toJson() => {
    'app': app,
    'formatVersion': formatVersion,
    'archiveId': archiveId,
    'counts': {
      'entries': entryCount,
      'activeEntries': activeEntryCount,
      'archivedEntries': archivedEntryCount,
      'deletedEntries': deletedEntryCount,
      'corrections': correctionCount,
      'evidenceLinks': evidenceLinkCount,
      'audioReferences': audioReferenceCount,
      'changeThreads': changeThreadCount,
      'changeEvents': changeEventCount,
      'unplacedChangeEvents': unplacedChangeEventCount,
      'weeklyReviews': weeklyReviewCount,
    },
    'audioPolicy': audioPolicy,
    'audioNote': audioNote,
    'accessNote': accessNote,
    'determinismNote': determinismNote,
    'tombstoneNote': tombstoneNote,
    'ownershipPromises': ArchiveOwnershipCopy.all,
    'entryFields': entryFields,
    'changeFields': changeFields,
    'weeklyReviewFields': weeklyReviewFields,
  };

  List<String> get readableLines => [
    'Format version: $formatVersion',
    'Archive: $archiveId',
    'Saved moments: $entryCount '
        '(active $activeEntryCount, archived $archivedEntryCount, '
        'deleted $deletedEntryCount)',
    'Corrections: $correctionCount',
    'Evidence links: $evidenceLinkCount',
    'Audio references: $audioReferenceCount',
    'Changes threads: $changeThreadCount '
        '(events $changeEventCount, unplaced $unplacedChangeEventCount)',
    'Weekly reviews: $weeklyReviewCount',
    'Audio: $audioPolicy — $audioNote',
    'Access: $accessNote',
    'Determinism: $determinismNote',
    'Deleted moments: $tombstoneNote',
    'Moment fields: ${entryFields.join(', ')}',
    'Changes fields: ${changeFields.join(', ')}',
    'Weekly review fields: ${weeklyReviewFields.join(', ')}',
  ];
}

/// Both halves of one export: a document a person can read, and a file a
/// program can parse. Neither depends on the other to be complete.
class ArchiveExportBundle {
  const ArchiveExportBundle({
    required this.manifest,
    required this.machineReadableJson,
    required this.readableDocument,
  });

  static const String machineReadableFileName = 'archiveme_archive.json';
  static const String readableFileName = 'archiveme_archive.md';

  final ArchiveExportManifest manifest;

  /// Deterministic JSON. Parses back to every exported field.
  final String machineReadableJson;

  /// Deterministic Markdown covering the same content in reading order.
  final String readableDocument;
}

/// Builds the complete, deterministic export of one archive.
///
/// The saved-moment aggregate and the existing Changes projection are the only
/// sources: this adds no second interpretation of the archive, it only
/// serialises what those two already agree on. Tombstones are included on
/// purpose so a reader can see that a moment was deleted rather than silently
/// missing.
abstract final class CompleteArchiveExportBuilder {
  static ArchiveExportBundle build({
    required String archiveId,
    required List<JournalEntry> entries,
    ChangeThreadProjection changes = const ChangeThreadProjection.empty(),
    Iterable<WeeklyReview> weeklyReviews = const [],
  }) {
    final ordered = _orderedEntries(entries);
    final threads = _orderedThreads(changes);
    final unplaced = _orderedEvents(changes.ungroupedEvents);
    final reviews = weeklyReviews.toList()
      ..sort((a, b) {
        final byDate = a.generatedAt.toUtc().compareTo(b.generatedAt.toUtc());
        return byDate != 0 ? byDate : a.reviewId.compareTo(b.reviewId);
      });

    final manifest = ArchiveExportManifest(
      archiveId: archiveId,
      entryCount: ordered.length,
      activeEntryCount: ordered
          .where((entry) => !entry.isDeleted && !entry.isArchived)
          .length,
      archivedEntryCount: ordered
          .where((entry) => !entry.isDeleted && entry.isArchived)
          .length,
      deletedEntryCount: ordered.where((entry) => entry.isDeleted).length,
      correctionCount: ordered.fold(
        0,
        (total, entry) => total + entry.textEdits.length,
      ),
      evidenceLinkCount: ordered.fold(
        0,
        (total, entry) => total + entry.evidenceOffsets.length,
      ),
      audioReferenceCount: ordered
          .where((entry) => entry.localAudioReference != null)
          .length,
      changeThreadCount: threads.length,
      changeEventCount: threads.fold(
        0,
        (total, view) => total + view.events.length,
      ),
      unplacedChangeEventCount: unplaced.length,
      weeklyReviewCount: reviews.length,
    );

    return ArchiveExportBundle(
      manifest: manifest,
      machineReadableJson: _machineReadable(
        manifest: manifest,
        entries: ordered,
        threads: threads,
        unplaced: unplaced,
        policyVersion: changes.policyVersion,
        weeklyReviews: reviews,
      ),
      readableDocument: _readable(
        manifest: manifest,
        entries: ordered,
        threads: threads,
        unplaced: unplaced,
        weeklyReviews: reviews,
      ),
    );
  }

  /// Reads the canonical journal — tombstones included — for one archive.
  static Future<ArchiveExportBundle> fromJournalStore(
    JournalStore journalStore, {
    ChangeThreadProjection changes = const ChangeThreadProjection.empty(),
    Iterable<WeeklyReview> weeklyReviews = const [],
  }) async => build(
    archiveId: journalStore.ownerArchiveId,
    entries: await journalStore.loadAll(includeDeleted: true),
    changes: changes,
    weeklyReviews: weeklyReviews,
  );

  // ——— Ordering ———

  static List<JournalEntry> _orderedEntries(List<JournalEntry> entries) =>
      entries.toList()..sort((a, b) {
        final byCreated = a.createdAt.toUtc().compareTo(b.createdAt.toUtc());
        return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
      });

  static List<ChangeThreadView> _orderedThreads(
    ChangeThreadProjection changes,
  ) =>
      changes.threads.toList()
        ..sort((a, b) => a.thread.threadId.compareTo(b.thread.threadId));

  static List<ChangeEvent> _orderedEvents(Iterable<ChangeEvent> events) =>
      events.toList()..sort((a, b) {
        final byDate = a.occurredAt.toUtc().compareTo(b.occurredAt.toUtc());
        return byDate != 0 ? byDate : a.eventId.compareTo(b.eventId);
      });

  static List<SavedMomentTextEdit> _orderedCorrections(JournalEntry entry) =>
      entry.textEdits.toList()..sort((a, b) {
        final byDate = a.editedAt.toUtc().compareTo(b.editedAt.toUtc());
        if (byDate != 0) return byDate;
        final bySource = a.source.name.compareTo(b.source.name);
        return bySource != 0 ? bySource : a.text.compareTo(b.text);
      });

  static List<SavedMomentEvidenceOffset> _orderedEvidence(JournalEntry entry) =>
      entry.evidenceOffsets.toList()..sort((a, b) {
        final byStart = a.startUtf16.compareTo(b.startUtf16);
        if (byStart != 0) return byStart;
        final byEnd = a.endUtf16.compareTo(b.endUtf16);
        if (byEnd != 0) return byEnd;
        final byAudioStart = (a.audioStartMs ?? -1).compareTo(
          b.audioStartMs ?? -1,
        );
        return byAudioStart != 0
            ? byAudioStart
            : (a.audioEndMs ?? -1).compareTo(b.audioEndMs ?? -1);
      });

  // ——— Machine-readable ———

  static String _machineReadable({
    required ArchiveExportManifest manifest,
    required List<JournalEntry> entries,
    required List<ChangeThreadView> threads,
    required List<ChangeEvent> unplaced,
    required String policyVersion,
    required List<WeeklyReview> weeklyReviews,
  }) => const JsonEncoder.withIndent('  ').convert({
    'manifest': manifest.toJson(),
    'savedMoments': entries.map(_entryJson).toList(growable: false),
    'changes': {
      'policyVersion': policyVersion,
      'threads': threads.map(_threadJson).toList(growable: false),
      'unplacedEvents': unplaced.map(_eventJson).toList(growable: false),
    },
    'weeklyReviews': weeklyReviews
        .map((review) => review.toJson())
        .toList(growable: false),
  });

  static Map<String, Object?> _entryJson(JournalEntry entry) {
    final corrections = _orderedCorrections(entry);
    final evidence = _orderedEvidence(entry);
    final media = entry.mediaAttachments.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return {
      'id': entry.id,
      'ownerArchiveId': entry.ownerArchiveId,
      'source': entry.source.name,
      'schemaVersion': entry.schemaVersion,
      'state': stateOf(entry),
      'syncStatus': entry.syncStatus.name,
      'timestamps': {
        'createdAt': _iso(entry.createdAt),
        'updatedAt': _iso(entry.updatedAt),
        'deletedAt': _isoOrNull(entry.deletedAt),
        'pinnedAt': _isoOrNull(entry.pinnedAt),
        'archivedAt': _isoOrNull(entry.archivedAt),
      },
      'text': {
        'transcript': entry.transcript,
        'earliestRetainedText': earliestRetainedText(entry),
        'durationSeconds': entry.durationSeconds,
      },
      'corrections': [
        for (final correction in corrections)
          {
            'editedAt': _iso(correction.editedAt),
            'source': correction.source.name,
            'text': correction.text,
          },
      ],
      'evidenceLinks': [
        for (final link in evidence)
          {
            'startUtf16': link.startUtf16,
            'endUtf16': link.endUtf16,
            'audioStartMs': link.audioStartMs,
            'audioEndMs': link.audioEndMs,
            'quotedText': quotedText(entry.transcript, link),
          },
      ],
      'audio': audioJson(entry),
      'markers': _markersJson(entry),
      'interpretation': entry.reflection.toJson(),
      'mediaReferences': [
        for (final attachment in media) attachment.toPortableJson(),
      ],
    };
  }

  static Map<String, Object?> _markersJson(JournalEntry entry) => {
    'isPinned': entry.isPinned,
    'isArchived': entry.isArchived,
    'isDeleted': entry.isDeleted,
    'treatAsNew': entry.treatAsNew,
    'connectionApproved': entry.connectionApproved,
    'keepExactDetails': entry.keepExactDetails,
    'keepSeparate': entry.keepSeparate,
    'preserveOriginal': entry.preserveOriginal,
    'wasGrounded': entry.wasGrounded,
    'entryAboutness': entry.entryAboutness,
    'memorySurfacing': entry.memorySurfacing,
    'captureContextTag': entry.captureContextTag,
    'archiveThreadId': entry.archiveThreadId,
    'archivePackId': entry.archivePackId,
    'parentHookId': entry.parentHookId,
    'recurringThemes': entry.reflection.recurringThemes,
  };

  static Map<String, Object?> _threadJson(ChangeThreadView view) => {
    'threadId': view.thread.threadId,
    'label': view.thread.userEditableLabel,
    'labelIsUserConfirmed': view.thread.labelIsUserConfirmed,
    'subjectRepresentation': view.thread.subjectRepresentation.toList(
      growable: false,
    )..sort(),
    'firstObservedAt': _iso(view.thread.firstObservedAt),
    'latestObservedAt': _iso(view.thread.latestObservedAt),
    'currentStatus': view.thread.currentStatus.name,
    'correctionState': view.thread.correctionState.name,
    'visibilityState': view.thread.visibilityState.name,
    'policyVersion': view.thread.policyVersion,
    'savedMomentCount': view.savedMomentCount,
    'events': _orderedEvents(
      view.events,
    ).map(_eventJson).toList(growable: false),
  };

  static Map<String, Object?> _eventJson(ChangeEvent event) => {
    'eventId': event.eventId,
    'threadId': event.threadId,
    'occurredAt': _iso(event.occurredAt),
    'statement': event.statement,
    'status': event.status.name,
    'conclusionKind': event.conclusionKind.name,
    'changedDimensions': _dimensionNames(event),
    'confidenceBand': event.confidenceBand.name,
    'uncertainty': event.uncertainty,
    'alternativeExplanation': event.alternativeExplanation,
    'correctionState': event.correctionState.name,
    'evidence': [
      for (final citation in _orderedCitations(event))
        {
          'entryId': citation.entryId,
          'quote': citation.quote,
          'startUtf16': citation.startUtf16,
          'endUtf16': citation.endUtf16,
          'role': citation.role.name,
          'temporalRole': citation.temporalRole.name,
          'sourceCapturedAt': _isoOrNull(citation.sourceCapturedAt),
          'audioStartMs': citation.audioTimestampMs,
          'audioEndMs': citation.audioEndTimestampMs,
          'audioReference': citation.audioVaultReference,
        },
    ],
  };

  static List<String> _dimensionNames(ChangeEvent event) =>
      event.changedDimensions
          .map((dimension) => dimension.name)
          .toList(growable: true)
        ..sort();

  static List<TranscriptEvidenceCitation> _orderedCitations(
    ChangeEvent event,
  ) => event.exactEvidence.toList()
    ..sort((a, b) {
      final byEntry = a.entryId.compareTo(b.entryId);
      if (byEntry != 0) return byEntry;
      final byStart = a.startUtf16.compareTo(b.startUtf16);
      return byStart != 0 ? byStart : a.quote.compareTo(b.quote);
    });

  // ——— Readable ———

  static String _readable({
    required ArchiveExportManifest manifest,
    required List<JournalEntry> entries,
    required List<ChangeThreadView> threads,
    required List<ChangeEvent> unplaced,
    required List<WeeklyReview> weeklyReviews,
  }) {
    final lines = <String>[
      '# ArchiveMe archive export',
      '',
      for (final promise in ArchiveOwnershipCopy.all) promise,
      '',
      '## Manifest',
      '',
      for (final line in manifest.readableLines) '- $line',
      '',
      '## Saved moments',
    ];

    if (entries.isEmpty) {
      lines
        ..add('')
        ..add('No saved moments in this archive.');
    }

    var index = 0;
    for (final entry in entries) {
      index++;
      final corrections = _orderedCorrections(entry);
      final evidence = _orderedEvidence(entry);
      lines
        ..add('')
        ..add('### $index. ${_iso(entry.createdAt)} — ${stateOf(entry)}')
        ..add('')
        ..add('- Id: ${entry.id}')
        ..add('- Captured by: ${entry.source.name}')
        ..add('- Duration: ${entry.durationSeconds}s')
        ..add('- Last updated: ${_iso(entry.updatedAt)}');
      if (entry.deletedAt != null) {
        lines.add('- Deleted at: ${_iso(entry.deletedAt!)}');
      }
      lines
        ..add('- Audio: ${_readableAudio(entry)}')
        ..add('- Markers: ${_readableMarkers(entry)}')
        ..add('- Text:')
        ..add('')
        ..add('> ${_quoteBlock(entry.transcript)}')
        ..add('')
        ..add('- Corrections (${corrections.length}):');
      if (corrections.isEmpty) {
        lines.add('  - None recorded.');
      } else {
        for (final correction in corrections) {
          lines.add(
            '  - ${_iso(correction.editedAt)} (${correction.source.name}): '
            '${_singleLine(correction.text)}',
          );
        }
      }
      lines.add('- Evidence links (${evidence.length}):');
      if (evidence.isEmpty) {
        lines.add('  - None recorded.');
      } else {
        for (final link in evidence) {
          final quote = quotedText(entry.transcript, link);
          final audio = link.audioStartMs == null && link.audioEndMs == null
              ? ''
              : ' (audio ${link.audioStartMs ?? '?'}–${link.audioEndMs ?? '?'}ms)';
          lines.add(
            '  - ${link.startUtf16}–${link.endUtf16}'
            '${quote == null ? '' : ': ${_singleLine(quote)}'}$audio',
          );
        }
      }
      lines
        ..add('- Interpretation:')
        ..add(
          '  - Mood: ${entry.reflection.mood} '
          '(intensity ${entry.reflection.emotionalIntensity})',
        )
        ..add(
          '  - Observation: '
          '${_singleLine(entry.reflection.concreteObservation)}',
        )
        ..add(
          '  - Exact wording: '
          '${_singleLine(entry.reflection.exactLanguagePattern)}',
        )
        ..add(
          '  - Repeated signal: '
          '${_singleLine(entry.reflection.repeatedSignal)}',
        )
        ..add(
          '  - Recurring themes: '
          '${entry.reflection.recurringThemes.isEmpty ? 'none' : entry.reflection.recurringThemes.join(', ')}',
        );
    }

    lines
      ..add('')
      ..add('## Changes history');

    if (threads.isEmpty) {
      lines
        ..add('')
        ..add('No threads have been observed yet.');
    }

    for (final view in threads) {
      lines
        ..add('')
        ..add('### Thread: ${view.thread.userEditableLabel}')
        ..add('')
        ..add('- Thread id: ${view.thread.threadId}')
        ..add('- Status: ${view.thread.currentStatus.name}')
        ..add('- First observed: ${_iso(view.thread.firstObservedAt)}')
        ..add('- Latest observed: ${_iso(view.thread.latestObservedAt)}')
        ..add('- Correction state: ${view.thread.correctionState.name}')
        ..add('- Saved moments behind it: ${view.savedMomentCount}')
        ..add('- Events (${view.events.length}):');
      for (final event in _orderedEvents(view.events)) {
        lines
          ..add(
            '  - ${_iso(event.occurredAt)}: ${_singleLine(event.statement)}',
          )
          ..add(
            '    - Reading: ${event.status.name}; '
            'confidence ${event.confidenceBand.name}; '
            'dimensions ${_dimensionNames(event).isEmpty ? 'none' : _dimensionNames(event).join(', ')}',
          )
          ..add('    - Uncertainty: ${_singleLine(event.uncertainty)}')
          ..add(
            '    - Alternative: ${_singleLine(event.alternativeExplanation)}',
          );
        for (final citation in _orderedCitations(event)) {
          lines.add(
            '    - Evidence from ${citation.entryId} '
            '[${citation.startUtf16}–${citation.endUtf16}]: '
            '${_singleLine(citation.quote)}',
          );
        }
      }
    }

    lines
      ..add('')
      ..add('### Findings not placed on a thread (${unplaced.length})');
    if (unplaced.isEmpty) {
      lines
        ..add('')
        ..add('- None.');
    } else {
      lines.add('');
      for (final event in unplaced) {
        lines.add(
          '- ${_iso(event.occurredAt)}: ${_singleLine(event.statement)}',
        );
      }
    }

    lines
      ..add('')
      ..add('## Weekly review history');
    if (weeklyReviews.isEmpty) {
      lines
        ..add('')
        ..add('No weekly reviews have been retained.');
    } else {
      for (final review in weeklyReviews) {
        lines
          ..add('')
          ..add('### ${_iso(review.windowStart)} to ${_iso(review.windowEnd)}')
          ..add('')
          ..add('- Review id: ${review.reviewId}')
          ..add('- Generated: ${_iso(review.generatedAt)}')
          ..add('- Policy: ${review.policyVersion}');
        for (final item in review.items) {
          lines
            ..add(
              '- ${item.kind.label}: ${_singleLine(item.statement)} '
              '(thread ${item.threadLabel})',
            )
            ..add('  - Event: ${item.eventId}; at ${_iso(item.occurredAt)}');
          for (final citation in item.evidence) {
            lines.add(
              '  - Evidence from ${citation.entryId} '
              '[${citation.startUtf16}–${citation.endUtf16}]: '
              '${_singleLine(citation.quote)}',
            );
          }
        }
      }
    }

    return '${lines.join('\n')}\n';
  }

  static String _readableAudio(JournalEntry entry) {
    final audio = audioJson(entry);
    if (audio['referenceKind'] == 'none') return 'no recording retained';
    return '${audio['referenceKind']} reference ${audio['reference']} '
        '(bytes not included)';
  }

  static String _readableMarkers(JournalEntry entry) {
    final markers = <String>[
      if (entry.isPinned) 'pinned',
      if (entry.isArchived) 'archived',
      if (entry.isDeleted) 'deleted',
      if (entry.treatAsNew) 'treat as new',
      if (entry.keepExactDetails) 'keep exact details',
      if (entry.keepSeparate) 'keep separate',
      if (entry.preserveOriginal) 'preserve original',
      if (entry.connectionApproved) 'connection approved',
      'about: ${entry.entryAboutness}',
      'surfacing: ${entry.memorySurfacing}',
    ];
    return markers.join('; ');
  }

  // ——— Shared field derivation ———

  /// `active`, `archived`, or `deleted` — a tombstone is never silently absent.
  static String stateOf(JournalEntry entry) {
    if (entry.isDeleted) return 'deleted';
    return entry.isArchived ? 'archived' : 'active';
  }

  /// The oldest text ArchiveMe still holds for this moment.
  ///
  /// Corrections are appended in order, so the first one is the wording that
  /// existed before the most recent edits. With no corrections the transcript
  /// is itself the original.
  static String earliestRetainedText(JournalEntry entry) {
    final corrections = _orderedCorrections(entry);
    return corrections.isEmpty ? entry.transcript : corrections.first.text;
  }

  /// The exported audio reference, never raw device bytes.
  ///
  /// A vault reference is already opaque and app-local, so it travels as-is. A
  /// legacy plaintext capture contributes its file name only, because the
  /// directory it sat in describes the device rather than the archive.
  static Map<String, Object?> audioJson(JournalEntry entry) {
    final vault = entry.localAudioVaultRef?.trim();
    if (vault != null && vault.isNotEmpty) {
      return {
        'referenceKind': 'vault',
        'reference': vault,
        'bytesIncluded': false,
      };
    }
    final legacy = entry.localAudioPath?.trim();
    if (legacy != null && legacy.isNotEmpty) {
      return {
        'referenceKind': 'localFile',
        'reference': p.basename(legacy),
        'bytesIncluded': false,
      };
    }
    return {'referenceKind': 'none', 'reference': null, 'bytesIncluded': false};
  }

  /// The transcript slice an evidence link points at, or null when the link no
  /// longer fits the text it was recorded against.
  static String? quotedText(String transcript, SavedMomentEvidenceOffset link) {
    if (link.startUtf16 < 0 || link.endUtf16 > transcript.length) return null;
    if (link.endUtf16 <= link.startUtf16) return null;
    return transcript.substring(link.startUtf16, link.endUtf16);
  }

  static String _iso(DateTime value) => value.toUtc().toIso8601String();

  static String? _isoOrNull(DateTime? value) =>
      value == null ? null : _iso(value);

  static String _singleLine(String value) {
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? '(empty)' : collapsed;
  }

  static String _quoteBlock(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '(no text)' : trimmed.replaceAll('\n', '\n> ');
  }
}
