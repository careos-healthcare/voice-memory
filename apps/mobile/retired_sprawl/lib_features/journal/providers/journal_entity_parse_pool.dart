import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archiveme_mobile/features/journal/domain/task_node.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_entity_parse_isolate.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Small background isolate pool for SQLite row JSON decoding and map
/// normalization before Riverpod notifiers emit UI-facing state.
final class JournalEntityParsePool {
  JournalEntityParsePool({this.workerCount = 2});

  final int workerCount;

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  final _workers = <_ParseWorker>[];
  int _roundRobin = 0;
  Future<void>? _starting;

  Future<void> ensureStarted() {
    if (_workers.isNotEmpty || _isFlutterTest) {
      return Future<void>.value();
    }
    return _starting ??= _spawnWorkers();
  }

  Future<Map<String, JournalEntry>> parseJournalEntries(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const {};
    if (_isFlutterTest) {
      return parseJournalEntryRows(rows);
    }

    await ensureStarted();
    return _dispatch<Map<String, JournalEntry>>(
      kind: 'journalEntries',
      rows: rows,
    );
  }

  Future<Map<String, TaskNode>> parseTaskNodes(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const {};
    if (_isFlutterTest) {
      return parseTaskNodeRows(rows);
    }

    await ensureStarted();
    return _dispatch<Map<String, TaskNode>>(
      kind: 'taskNodes',
      rows: rows,
    );
  }

  Future<T> _dispatch<T>({
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (_workers.isEmpty) {
      throw StateError('JournalEntityParsePool workers are not running');
    }

    final worker = _workers[_roundRobin % _workers.length];
    _roundRobin++;
    return worker.run<T>(kind: kind, rows: rows);
  }

  Future<void> _spawnWorkers() async {
    for (var index = 0; index < workerCount; index++) {
      final worker = _ParseWorker();
      await worker.start();
      _workers.add(worker);
    }
  }

  Future<void> dispose() async {
    for (final worker in _workers) {
      await worker.dispose();
    }
    _workers.clear();
    _starting = null;
  }
}

final class _ParseWorker {
  SendPort? _workerPort;
  Isolate? _isolate;

  Future<void> start() async {
    final handshake = ReceivePort();
    _isolate = await Isolate.spawn(
      journalEntityParseWorkerMain,
      handshake.sendPort,
      debugName: 'journal_entity_parse_worker',
    );
    _workerPort = await handshake.first as SendPort;
    handshake.close();
  }

  Future<T> run<T>({
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async {
    final workerPort = _workerPort;
    if (workerPort == null) {
      throw StateError('Parse worker is not started');
    }

    final responsePort = ReceivePort();
    workerPort.send({
      'kind': kind,
      'rows': rows,
      'replyPort': responsePort.sendPort,
    });

    final result = await responsePort.first;
    responsePort.close();
    return result as T;
  }

  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _workerPort = null;
  }
}
