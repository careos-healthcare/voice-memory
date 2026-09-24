import 'package:archiveme_mobile/services/markdown_export_service.dart';

/// Values a user template can place in an Obsidian note.
class ObsidianTemplateValues {
  const ObsidianTemplateValues({
    required this.id,
    required this.date,
    required this.mood,
    required this.tags,
    required this.transcript,
    required this.patterns,
    this.extractedTags = '',
    this.locality = '',
    this.weather = '',
    this.steps = '',
    this.calendar = '',
  });

  factory ObsidianTemplateValues.fromNote(MarkdownNote note) {
    final tags = note.tags.where((tag) => tag.trim().isNotEmpty);
    return ObsidianTemplateValues(
      id: note.id,
      date: note.createdAt.toUtc().toIso8601String().split('T').first,
      mood: note.mood,
      tags: tags.map((tag) => '  - $tag').join('\n'),
      transcript: note.body.trim(),
      patterns: note.patterns
          .map((pattern) => pattern.trim())
          .where((pattern) => pattern.isNotEmpty)
          .map((pattern) => '- $pattern')
          .join('\n'),
      extractedTags: note.extractedTags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .map((tag) => '  - $tag')
          .join('\n'),
      locality: note.ambient.locality?.trim() ?? '',
      weather: note.ambient.weather?.trim() ?? '',
      steps: note.ambient.steps?.toString() ?? '',
      calendar: note.ambient.calendar?.trim() ?? '',
    );
  }

  final String id;
  final String date;
  final String mood;
  final String tags;
  final String transcript;
  final String patterns;
  final String extractedTags;
  final String locality;
  final String weather;
  final String steps;
  final String calendar;

  Map<String, String> toMap() => {
    'id': id,
    'date': date,
    'mood': mood,
    'tags': tags,
    'transcript': transcript,
    'patterns': patterns,
    'extracted_tags': extractedTags,
    'locality': locality,
    'weather': weather,
    'steps': steps,
    'calendar': calendar,
  };
}

/// User-owned layout for transcripts, metadata, and synthesized patterns.
///
/// `{{name}}` inserts a value. `{{#name}}...{{/name}}` is omitted when that
/// value is empty, so unused metadata does not appear in the note.
class ObsidianMarkdownTemplate {
  const ObsidianMarkdownTemplate(this.source);

  final String source;

  static const defaultSource = '''
---
date: {{date}}
tags:
{{tags}}
mood: {{mood}}
{{#extracted_tags}}extracted_tags:
{{extracted_tags}}
{{/extracted_tags}}
{{#locality}}ambient_locality: {{locality}}
{{/locality}}{{#weather}}ambient_weather: {{weather}}
{{/weather}}{{#steps}}ambient_steps: {{steps}}
{{/steps}}{{#calendar}}ambient_calendar: {{calendar}}
{{/calendar}}---

{{transcript}}
{{#patterns}}
## Patterns
{{patterns}}
{{/patterns}}
''';

  String render(ObsidianTemplateValues values) {
    final map = values.toMap();
    final sections = RegExp(r'\{\{#(\w+)\}\}([\s\S]*?)\{\{/\1\}\}');
    final withSections = source.replaceAllMapped(sections, (match) {
      final key = match.group(1)!;
      final body = match.group(2)!;
      final value = map[key] ?? '';
      if (value.trim().isEmpty) return '';
      return body.replaceAll('{{$key}}', value);
    });
    return withSections.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (match) {
      return map[match.group(1)!] ?? '';
    });
  }
}
