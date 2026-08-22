import 'package:archiveme_mobile/features/archive_search/archive_search_model.dart';
import 'package:archiveme_mobile/features/moments/moment_tag_model.dart';

/// Parses natural-language prompts into constrained search intents.
ArchiveSearchQuery parseArchiveSearchQuery(String text) {
  final raw = text.trim();
  final lower = raw.toLowerCase();

  if (lower.isEmpty) {
    return ArchiveSearchQuery(
      intent: ArchiveSearchIntent.freeText,
      rawText: raw,
    );
  }

  if (lower.contains('this week') || lower.contains('changed this week')) {
    return ArchiveSearchQuery(
      intent: lower.contains('changed')
          ? ArchiveSearchIntent.changed
          : ArchiveSearchIntent.thisWeek,
      rawText: raw,
    );
  }

  if (lower.contains('what helped') || lower.contains('helped before')) {
    return ArchiveSearchQuery(
      intent: ArchiveSearchIntent.helpedBefore,
      rawText: raw,
    );
  }

  if (lower.contains('felt lighter') || lower.contains('feel lighter')) {
    return ArchiveSearchQuery(
      intent: ArchiveSearchIntent.feltLighter,
      rawText: raw,
    );
  }

  if (lower.contains('felt heavier') || lower.contains('feel heavier')) {
    return ArchiveSearchQuery(
      intent: ArchiveSearchIntent.feltHeavier,
      rawText: raw,
    );
  }

  if (lower.contains('changed')) {
    return ArchiveSearchQuery(
      intent: ArchiveSearchIntent.changed,
      rawText: raw,
    );
  }

  if (lower.contains('last show') ||
      lower.contains('show up') ||
      lower.contains('showed up')) {
    return ArchiveSearchQuery(
      intent: ArchiveSearchIntent.lastSeen,
      rawText: raw,
    );
  }

  final topic = _topicTermFrom(lower);
  if (topic != null &&
      (lower.contains('about') || lower.contains('moments about'))) {
    return ArchiveSearchQuery(
      intent: ArchiveSearchIntent.momentsAbout,
      rawText: raw,
      normalizedTerm: topic,
    );
  }

  return ArchiveSearchQuery(intent: ArchiveSearchIntent.freeText, rawText: raw);
}

String? _topicTermFrom(String lower) {
  for (final tag in MomentTag.values) {
    if (lower.contains(tag.id)) return tag.id;
  }
  return null;
}