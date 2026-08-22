import 'package:archiveme_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:archiveme_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/features/pattern_map/pattern_map_model.dart';

/// One recurring pattern brought together in a single profile view.
class PatternProfile {
  const PatternProfile({
    required this.patternTitle,
    this.archiveMemorySummary,
    this.patternMap,
    this.archiveEvolutionTimeline,
    this.keyMoments = const [],
    this.nextCheck,
    this.clarityLabel,
  });

  final String patternTitle;
  final ArchiveMemorySummary? archiveMemorySummary;
  final PatternMap? patternMap;
  final ArchiveEvolutionTimeline? archiveEvolutionTimeline;
  final List<KeyMoment> keyMoments;
  final String? nextCheck;
  final String? clarityLabel;

  bool get hasMemorySummary => archiveMemorySummary != null;
  bool get hasMap => patternMap != null;
  bool get hasTimeline => archiveEvolutionTimeline != null;
  bool get hasKeyMoments => keyMoments.isNotEmpty;
  bool get hasNextCheck => (nextCheck ?? '').trim().isNotEmpty;
}