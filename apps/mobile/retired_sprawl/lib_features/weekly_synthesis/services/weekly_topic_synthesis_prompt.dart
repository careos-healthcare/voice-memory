import 'dart:convert';

import 'package:archiveme_mobile/features/weekly_synthesis/domain/recurrent_topic_cluster.dart';

/// Prompt + JSON parsing for weekly Gemma synthesis over recurrent topics.
abstract final class WeeklyTopicSynthesisPrompt {
  WeeklyTopicSynthesisPrompt._();

  static String build({
    required List<RecurrentTopicCluster> topics,
    required String weekLabel,
  }) {
    final buffer = StringBuffer()
      ..writeln('Synthesize recurring reflection themes from the past week.')
      ..writeln('Week: $weekLabel')
      ..writeln('Recurrent topics (label × mention count):');

    for (final topic in topics) {
      buffer.writeln('- ${topic.displayLabel} (${topic.mentionCount} mentions)');
    }

    buffer
      ..writeln()
      ..writeln('Return JSON only with this schema:')
      ..writeln('{')
      ..writeln('  "headline": "short title (max 12 words)",')
      ..writeln('  "summary": "2-4 calm sentences connecting the themes",')
      ..writeln('  "recurringThemes": ["theme labels echoed from input"]')
      ..writeln('}');

    return buffer.toString();
  }

  static WeeklyTopicSynthesisDraft parse({
    required String rawCompletion,
    required List<RecurrentTopicCluster> topics,
  }) {
    final decoded = _decodeJsonObject(rawCompletion);
    final headline = _readString(decoded['headline'])?.trim();
    final summary = _readString(decoded['summary'])?.trim();
    if (headline == null ||
        headline.isEmpty ||
        summary == null ||
        summary.isEmpty) {
      throw FormatException('Missing headline or summary in synthesis JSON');
    }

    final themes = _parseStringList(decoded['recurringThemes']);
    final fallbackThemes = topics.map((t) => t.displayLabel).toList();
    return WeeklyTopicSynthesisDraft(
      headline: headline,
      summary: summary,
      recurringThemeLabels: themes.isEmpty ? fallbackThemes : themes,
    );
  }

  static Map<String, dynamic> _decodeJsonObject(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty synthesis completion');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start < 0 || end <= start) rethrow;
      decoded = jsonDecode(trimmed.substring(start, end + 1));
    }

    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Expected JSON object, got ${decoded.runtimeType}');
    }
    return decoded;
  }

  static String? _readString(Object? value) => value is String ? value : null;

  static List<String> _parseStringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

final class WeeklyTopicSynthesisDraft {
  const WeeklyTopicSynthesisDraft({
    required this.headline,
    required this.summary,
    required this.recurringThemeLabels,
  });

  final String headline;
  final String summary;
  final List<String> recurringThemeLabels;
}
