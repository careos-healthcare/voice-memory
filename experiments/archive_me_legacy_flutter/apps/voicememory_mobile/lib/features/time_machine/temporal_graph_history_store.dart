import '../../core/graph/personal_knowledge_graph.dart';
import '../../storage/encrypted_json_file_store.dart';

class TemporalGraphHistoryStore {
  TemporalGraphHistoryStore({
    required EncryptedJsonFileStore storage,
    DateTime Function()? clock,
    // ignore: prefer_initializing_formals
  }) : _storage = storage,
       _clock = clock ?? DateTime.now;

  final EncryptedJsonFileStore _storage;
  final DateTime Function() _clock;
  Future<void> _tail = Future<void>.value();

  Future<void> append(PersonalKnowledgeGraph graph) {
    final operation = _tail.then((_) async {
      final rows = await _read();
      final graphJson = graph.toJson();
      if (rows.isNotEmpty && _sameGraph(rows.last['graph'], graphJson)) return;
      rows.add({
        'capturedAt': _clock().toUtc().toIso8601String(),
        'graph': graphJson,
      });
      await _storage.writeJson({'schemaVersion': 1, 'snapshots': rows});
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<PersonalKnowledgeGraph?> snapshotAt(DateTime targetTime) async {
    await _tail;
    final target = targetTime.toUtc();
    Map<String, dynamic>? selected;
    for (final row in await _read()) {
      final captured = DateTime.tryParse('${row['capturedAt']}')?.toUtc();
      if (captured == null || captured.isAfter(target)) continue;
      selected = row;
    }
    final raw = selected?['graph'];
    return raw is Map
        ? PersonalKnowledgeGraph.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }

  Future<void> clear() async {
    await _tail;
    await _storage.writeJson(const <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final document = await _storage.readJson();
    if (document is! Map) return [];
    return (document['snapshots'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  bool _sameGraph(Object? left, Map<String, dynamic> right) =>
      left is Map && left.toString() == right.toString();
}
