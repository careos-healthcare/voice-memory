import 'package:archiveme_mobile/features/search/data/embedded_node.dart';
import 'package:archiveme_mobile/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens and owns the ObjectBox [Store] backing on-device HNSW retrieval.
final class HybridSearchObjectBoxStore {
  HybridSearchObjectBoxStore._(this.store);

  /// Opens a store at [directory] synchronously (tests / isolates).
  HybridSearchObjectBoxStore.openSync({required String directory})
      : store = Store(getObjectBoxModel(), directory: directory);

  final Store store;

  Box<EmbeddedNode> get embeddedNodeBox => store.box<EmbeddedNode>();

  /// Opens (or creates) the hybrid-search ObjectBox store under app documents.
  static Future<HybridSearchObjectBoxStore> open({String? directory}) async {
    final resolvedDirectory = directory ?? await _defaultDirectory();
    final store = await openStore(directory: resolvedDirectory);
    return HybridSearchObjectBoxStore._(store);
  }

  static Future<String> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'hybrid_search_objectbox');
  }

  void close() => store.close();
}
