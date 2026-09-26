import 'dart:convert';

import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart';
import 'package:archiveme_mobile/features/insights/knowledge_catalog.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Labels the person asked Thoughtprint to stop treating as known.
class ForgottenKnowledge {
  ForgottenKnowledge._();

  static const preferenceKey = 'forgotten_knowledge_labels';

  static Future<Set<String>> load(MobilePrefsStore prefs) async {
    final raw = await prefs.readString(preferenceKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return {
        for (final item in decoded)
          if (item is String && item.trim().isNotEmpty)
            item.trim().toLowerCase(),
      };
    } on Object {
      return {};
    }
  }

  static Future<void> remember(MobilePrefsStore prefs, String label) async {
    final next = await load(prefs);
    final key = label.trim().toLowerCase();
    if (key.isEmpty) return;
    next.add(key);
    final labels = next.toList()..sort();
    await prefs.writeString(preferenceKey, jsonEncode(labels));
  }
}

/// Drops forgotten labels from text that would be sent to the cloud ledger.
String omitForgottenLabels(String transcript, Set<String> labels) {
  var text = transcript;
  for (final label in labels) {
    final key = label.trim();
    if (key.length < 3) continue;
    text = text.replaceAll(
      RegExp(RegExp.escape(key), caseSensitive: false),
      ' ',
    );
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Drops a person, place, or theme locally, and from the cloud ledger when
/// cloud features are on.
class KnowledgeForgetService {
  KnowledgeForgetService({
    Future<void> Function(String label)? deleteCloudLabel,
    Future<bool> Function()? isCloudSyncEnabled,
  }) : _deleteCloudLabel = deleteCloudLabel ?? _deleteOnServer,
       _isCloudSyncEnabled = isCloudSyncEnabled ?? _cloudIsOn;

  static const cloudPath = '/api/ledger/entity';

  final Future<void> Function(String label) _deleteCloudLabel;
  final Future<bool> Function() _isCloudSyncEnabled;

  Future<void> forget(KnowledgeItem item) async {
    if (!AppServices.isInitialized) {
      if (await _isCloudSyncEnabled()) {
        await _deleteCloudLabel(item.label);
      }
      return;
    }
    final prefs = AppServices.instance.prefs;
    await ForgottenKnowledge.remember(prefs, item.label);
    final entries = await AppServices.instance.journalStore.loadAll();
    for (final cited in item.citations) {
      JournalEntry? current;
      for (final entry in entries) {
        if (entry.id == cited.id) {
          current = entry;
          break;
        }
      }
      if (current == null) continue;
      final next = entryWithoutKnowledge(current, item);
      if (next == null) continue;
      await AppServices.instance.journalStore.save(next);
    }
    if (item.factIds.isNotEmpty) {
      final facts = FactLedgerStore.instance();
      for (final id in item.factIds) {
        await facts.delete(id);
      }
    }
    if (await _isCloudSyncEnabled()) {
      try {
        await _deleteCloudLabel(item.label);
      } on Object {
        return;
      }
    }
  }

  static Future<bool> _cloudIsOn() async {
    if (!AppServices.isInitialized) return false;
    final preferences = await UserPreferences.load(AppServices.instance.prefs);
    return preferences.isCloudSyncEnabled;
  }

  static Future<void> _deleteOnServer(String label) async {
    if (!AppServices.isInitialized) return;
    final trimmed = label.trim();
    if (trimmed.length < 3) return;
    await AppServices.instance.httpTransport.delete(
      cloudPath,
      body: {'label': trimmed},
    );
  }
}
