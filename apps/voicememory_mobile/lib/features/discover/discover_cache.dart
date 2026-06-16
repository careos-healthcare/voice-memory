import '../../models/journal_entry.dart';
import 'discover_models.dart';

/// In-memory memoization for Discover Yourself (<100ms reopen when fingerprint matches).
class DiscoverYourselfCache {
  DiscoverYourselfCache._();

  static DiscoverYourselfCache? _instance;
  static DiscoverYourselfCache get instance =>
      _instance ??= DiscoverYourselfCache._();

  DiscoverYourselfSnapshot? _snapshot;
  String? _fingerprint;
  DateTime? _cachedAt;

  static String fingerprint(List<JournalEntry> entries) {
    if (entries.isEmpty) return 'empty';
    final sorted = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final last = sorted.last;
    return '${entries.length}:${last.id}:${last.createdAt.millisecondsSinceEpoch}';
  }

  DiscoverYourselfSnapshot? getIfValid(String fp) {
    if (_snapshot == null || _fingerprint != fp) return null;
    return _snapshot;
  }

  void put(String fp, DiscoverYourselfSnapshot snapshot) {
    _fingerprint = fp;
    _snapshot = snapshot;
    _cachedAt = DateTime.now();
  }

  void invalidate() {
    _fingerprint = null;
    _snapshot = null;
    _cachedAt = null;
  }

  DateTime? get cachedAt => _cachedAt;
}
