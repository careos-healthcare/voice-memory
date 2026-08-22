import 'package:archiveme_mobile/features/weekly_synthesis/weekly_synthesis_config.dart';

/// On-device Gemma synthesis saved as a reflection-graph node.
class WeeklyTopicSynthesis {
  const WeeklyTopicSynthesis({
    required this.weekStart,
    required this.weekKey,
    required this.headline,
    required this.summary,
    required this.sourceNodeIds,
    required this.recurringThemeLabels,
    required this.generatedAt,
  });

  final DateTime weekStart;
  final String weekKey;
  final String headline;
  final String summary;
  final List<String> sourceNodeIds;
  final List<String> recurringThemeLabels;
  final DateTime generatedAt;

  String get entryId => '${WeeklySynthesisConfig.synthesisEntryIdPrefix}:$weekKey';
  String get nodeId => '$entryId:summary';
}
