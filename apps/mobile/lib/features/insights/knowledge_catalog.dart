import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/insights/recurring_themes_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

enum KnowledgeKind { people, places, themes }

/// One recurring person, place, or theme, with the entries that mention it.
class KnowledgeItem {
  const KnowledgeItem({
    required this.kind,
    required this.label,
    required this.citations,
    this.factIds = const [],
  });

  final KnowledgeKind kind;
  final String label;
  final List<JournalEntry> citations;
  final List<String> factIds;

  List<String> get entryIds => [for (final entry in citations) entry.id];
}

/// Groups saved people, places, and themes. [forgotten] labels stay hidden.
List<KnowledgeItem> buildKnowledgeCatalog(
  List<JournalEntry> entries, {
  List<ArchiveFact> contacts = const [],
  Set<String> forgotten = const {},
}) {
  final hidden = {for (final label in forgotten) label.trim().toLowerCase()};
  bool kept(String label) {
    final key = label.trim().toLowerCase();
    return key.isNotEmpty && !hidden.contains(key);
  }

  final byId = {for (final entry in entries) entry.id: entry};
  final people = <String, KnowledgeItem>{};
  for (final fact in contacts) {
    if (fact.factType != FactType.contact.id) continue;
    final label = fact.label.trim();
    if (!kept(label)) continue;
    final key = label.toLowerCase();
    final existing = people[key];
    final cited = byId[fact.sourceEntryId];
    people[key] = KnowledgeItem(
      kind: KnowledgeKind.people,
      label: existing?.label ?? label,
      citations: [
        ...?existing?.citations,
        if (cited != null &&
            (existing?.citations.every((entry) => entry.id != cited.id) ??
                true))
          cited,
      ],
      factIds: [...?existing?.factIds, fact.id],
    );
  }

  final places = <String, List<JournalEntry>>{};
  final placeLabels = <String, String>{};
  for (final entry in entries) {
    final label = entry.display.locationLabel?.trim() ?? '';
    if (!kept(label)) continue;
    final key = label.toLowerCase();
    placeLabels[key] = label;
    final bucket = places.putIfAbsent(key, () => []);
    if (bucket.every((saved) => saved.id != entry.id)) bucket.add(entry);
  }

  final themes = <String, List<JournalEntry>>{};
  final themeLabels = <String, String>{};
  for (final entry in entries) {
    for (final raw in entry.reflection.recurringThemes) {
      final label = plainThemeLabel(raw);
      if (!kept(label)) continue;
      final key = label.toLowerCase();
      themeLabels[key] = label;
      final bucket = themes.putIfAbsent(key, () => []);
      if (bucket.every((saved) => saved.id != entry.id)) bucket.add(entry);
    }
  }

  KnowledgeItem item(
    KnowledgeKind kind,
    String label,
    List<JournalEntry> citations,
  ) {
    return KnowledgeItem(kind: kind, label: label, citations: citations);
  }

  final catalog = <KnowledgeItem>[
    for (final entry in people.entries) entry.value,
    for (final entry in places.entries)
      item(KnowledgeKind.places, placeLabels[entry.key]!, entry.value),
    for (final entry in themes.entries)
      item(KnowledgeKind.themes, themeLabels[entry.key]!, entry.value),
  ];
  catalog.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return catalog;
}

/// Removes a forgotten place or theme tag from one saved entry.
JournalEntry? entryWithoutKnowledge(JournalEntry entry, KnowledgeItem item) {
  final key = item.label.trim().toLowerCase();
  if (key.isEmpty) return null;
  switch (item.kind) {
    case KnowledgeKind.people:
      return null;
    case KnowledgeKind.places:
      final place = entry.display.locationLabel?.trim().toLowerCase() ?? '';
      if (place != key) return null;
      return entry.copyWith(
        display: entry.display.copyWith(locationLabel: null),
      );
    case KnowledgeKind.themes:
      final themes = entry.reflection.recurringThemes;
      final kept = [
        for (final theme in themes)
          if (plainThemeLabel(theme).toLowerCase() != key) theme,
      ];
      if (kept.length == themes.length) return null;
      return entry.copyWith(
        reflection: Reflection(
          mood: entry.reflection.mood,
          emotionalIntensity: entry.reflection.emotionalIntensity,
          recurringThemes: kept,
          exactLanguagePattern: entry.reflection.exactLanguagePattern,
          concreteObservation: entry.reflection.concreteObservation,
          repeatedSignal: entry.reflection.repeatedSignal,
          tensionOrContradiction: entry.reflection.tensionOrContradiction,
          avoidedOrVagueArea: entry.reflection.avoidedOrVagueArea,
          nextSmallAction: entry.reflection.nextSmallAction,
          patternObservations: entry.reflection.patternObservations,
          healthStateOfMind: entry.reflection.healthStateOfMind,
        ),
      );
  }
}
