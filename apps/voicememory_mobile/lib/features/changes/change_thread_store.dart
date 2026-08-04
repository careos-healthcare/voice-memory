import 'dart:async';
import 'dart:io';

import '../../storage/encrypted_json_file_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import 'change_thread.dart';
import 'change_thread_correction.dart';
import 'change_thread_projection.dart';

class ChangeThreadState {
  ChangeThreadState({
    required Iterable<ChangeThread> threads,
    required Iterable<ChangeEvent> events,
    required Iterable<ChangeThreadCorrection> corrections,
  }) : threads = List.unmodifiable(threads),
       events = List.unmodifiable(events),
       corrections = List.unmodifiable(corrections);

  const ChangeThreadState.empty()
    : threads = const [],
      events = const [],
      corrections = const [];

  final List<ChangeThread> threads;
  final List<ChangeEvent> events;
  final List<ChangeThreadCorrection> corrections;

  /// The last projection as the user left it, so Changes opens on the same
  /// threads after a restart instead of an empty screen while it re-derives.
  ChangeThreadProjection get projection => ChangeThreadProjection(
    threads:
        threads
            .where((thread) => thread.isVisible)
            .map(
              (thread) => ChangeThreadView(
                thread: thread,
                events: events.where(
                  (event) => event.threadId == thread.threadId,
                ),
              ),
            )
            .where((view) => view.events.isNotEmpty)
            .toList()
          ..sort(
            (a, b) =>
                b.thread.latestObservedAt.compareTo(a.thread.latestObservedAt),
          ),
    ungroupedEvents: events.where((event) => event.threadId.isEmpty),
    policyVersion: ChangeThreadProjector.policyVersion,
  );
}

/// Durable, archive-scoped home for Changes threads and user corrections.
///
/// Threads are partitioned per archive both physically — the file lives beside
/// that archive's journal — and logically, because every row carries its
/// owner and a read never returns another archive's thread.
class ChangeThreadStore {
  ChangeThreadStore({
    required File file,
    required PrivateDataEncryptionKeyStore keyStore,
    required this.archiveId,
    DateTime Function()? clock,
  }) : assert(archiveId != '', 'A thread store must belong to an archive.'),
       _storage = EncryptedJsonFileStore(file: file, keyStore: keyStore),
       _clock = clock ?? DateTime.now;

  static const storeVersion = 1;
  static const fileName = 'change_threads.enc';

  final EncryptedJsonFileStore _storage;
  final String archiveId;
  final DateTime Function() _clock;
  Future<void> _pending = Future.value();

  File get encryptedFile => _storage.file;

  Future<ChangeThreadState> read() => _serialized(_readOwned);

  Future<List<ChangeThreadCorrection>> corrections() async =>
      (await read()).corrections;

  /// Stores [projection] as the archive's current threads, keeping the user's
  /// corrections intact.
  Future<void> save(ChangeThreadProjection projection) => _serialized(() async {
    final current = await _readOwned();
    await _writeOwned(
      ChangeThreadState(
        threads: projection.threads.map((view) => view.thread),
        events: projection.allEvents,
        corrections: current.corrections,
      ),
    );
  });

  Future<ChangeThreadState> addCorrection(ChangeThreadCorrection correction) =>
      _serialized(() async {
        final current = await _readOwned();
        final next = ChangeThreadState(
          threads: current.threads,
          events: current.events,
          corrections: [...current.corrections, correction]
            ..sort((a, b) => a.at.compareTo(b.at)),
        );
        await _writeOwned(next);
        return next;
      });

  Future<ChangeThreadState> renameThread(String threadId, String label) =>
      addCorrection(
        RenameChangeThread(
          threadId: threadId,
          label: label,
          at: _clock().toUtc(),
        ),
      );

  Future<ChangeThreadState> splitThread(
    String threadId,
    Set<String> eventIds, {
    String? newLabel,
  }) => addCorrection(
    SplitChangeThread(
      threadId: threadId,
      eventIds: eventIds,
      newLabel: newLabel,
      at: _clock().toUtc(),
    ),
  );

  Future<ChangeThreadState> mergeThreads(
    String threadId,
    String intoThreadId,
  ) => addCorrection(
    MergeChangeThreads(
      threadId: threadId,
      intoThreadId: intoThreadId,
      at: _clock().toUtc(),
    ),
  );

  Future<ChangeThreadState> suppressFraming(
    String threadId, {
    String? eventId,
  }) => addCorrection(
    SuppressChangeThreadFraming(
      threadId: threadId,
      eventId: eventId,
      at: _clock().toUtc(),
    ),
  );

  Future<void> clear() =>
      _serialized(() => _writeOwned(const ChangeThreadState.empty()));

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, dynamic>> _readEnvelope() async {
    final raw = await _storage.readJson();
    if (raw is! Map) return {};
    final json = Map<String, dynamic>.from(raw);
    if (json['storeVersion'] != storeVersion) return {};
    final archives = json['archives'];
    return archives is Map ? Map<String, dynamic>.from(archives) : {};
  }

  Future<ChangeThreadState> _readOwned() async {
    final archives = await _readEnvelope();
    final mine = archives[archiveId];
    if (mine is! Map) return const ChangeThreadState.empty();
    final json = Map<String, dynamic>.from(mine);
    final threads = (json['threads'] as List? ?? const [])
        .map(ChangeThread.fromJson)
        .whereType<ChangeThread>()
        .where((thread) => thread.archiveId == archiveId)
        .toList(growable: false);
    final owned = threads.map((thread) => thread.threadId).toSet();
    return ChangeThreadState(
      threads: threads,
      events: (json['events'] as List? ?? const [])
          .map(ChangeEvent.fromJson)
          .whereType<ChangeEvent>()
          .where(
            (event) => event.threadId.isEmpty || owned.contains(event.threadId),
          )
          .toList(growable: false),
      corrections: (json['corrections'] as List? ?? const [])
          .map(ChangeThreadCorrection.fromJson)
          .whereType<ChangeThreadCorrection>()
          .toList(growable: false),
    );
  }

  Future<void> _writeOwned(ChangeThreadState state) async {
    final archives = await _readEnvelope();
    archives[archiveId] = {
      'threads': state.threads
          .map((thread) => thread.toJson())
          .toList(growable: false),
      'events': state.events
          .map((event) => event.toJson())
          .toList(growable: false),
      'corrections': state.corrections
          .map((correction) => correction.toJson())
          .toList(growable: false),
    };
    await _storage.writeJson({
      'storeVersion': storeVersion,
      'archives': archives,
    });
  }
}
