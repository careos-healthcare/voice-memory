import 'dart:convert';
import 'dart:io';

import '../models/journal_entry.dart';

/// Durable JSON journal file on device.
class JournalStore {
  JournalStore({required this.file});

  final File file;

  static Future<JournalStore> open(String filePath) async {
    final file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    if (!await file.exists()) {
      await file.writeAsString('[]');
    }
    return JournalStore(file: file);
  }

  Future<List<JournalEntry>> loadAll() async {
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final entries = list
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> save(JournalEntry entry) async {
    final all = await loadAll();
    final next = [entry, ...all.where((e) => e.id != entry.id)];
    await _writeAll(next);
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    await _writeAll(all.where((e) => e.id != id).toList());
  }

  Future<JournalEntry?> getById(String id) async {
    final all = await loadAll();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<String> exportJson() async {
    final all = await loadAll();
    return const JsonEncoder.withIndent('  ').convert(
      all.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> _writeAll(List<JournalEntry> entries) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await file.writeAsString(encoded);
  }
}
