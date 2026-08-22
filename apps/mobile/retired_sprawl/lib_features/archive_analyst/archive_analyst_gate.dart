import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// When the Archive Analyst report may be generated.
abstract class ArchiveAnalystGate {
  ArchiveAnalystGate._();

  static const int level1Threshold = 50;
  static const int level2Threshold = 100;
  static const int level3Threshold = 200;

  static int eligibleCount(List<JournalEntry> entries) =>
      archiveEvidenceReflectionCount(entries);

  static ArchiveAnalystLevel levelFor(int eligibleReflectionCount) {
    if (eligibleReflectionCount < level1Threshold) {
      return ArchiveAnalystLevel.insufficient;
    }
    if (eligibleReflectionCount >= level3Threshold) {
      return ArchiveAnalystLevel.level3;
    }
    if (eligibleReflectionCount >= level2Threshold) {
      return ArchiveAnalystLevel.level2;
    }
    return ArchiveAnalystLevel.level1;
  }

  static bool canGenerateReport(int eligibleReflectionCount) =>
      levelFor(eligibleReflectionCount) != ArchiveAnalystLevel.insufficient;

  static int reflectionsUntilLevel1(int eligibleReflectionCount) =>
      (level1Threshold - eligibleReflectionCount).clamp(0, level1Threshold);
}

enum ArchiveAnalystLevel { insufficient, level1, level2, level3 }

extension ArchiveAnalystLevelLabels on ArchiveAnalystLevel {
  String get reportTitle => switch (this) {
    ArchiveAnalystLevel.insufficient => 'Archive Analyst',
    ArchiveAnalystLevel.level1 => 'Analyst Report · Level 1',
    ArchiveAnalystLevel.level2 => 'Analyst Report · Level 2',
    ArchiveAnalystLevel.level3 => 'Analyst Report · Level 3',
  };

  int get maxCurrentBeliefs => switch (this) {
    ArchiveAnalystLevel.insufficient => 0,
    ArchiveAnalystLevel.level1 => 4,
    ArchiveAnalystLevel.level2 => 6,
    ArchiveAnalystLevel.level3 => 8,
  };

  int get maxEmergingOrFading => switch (this) {
    ArchiveAnalystLevel.insufficient => 0,
    ArchiveAnalystLevel.level1 => 2,
    ArchiveAnalystLevel.level2 => 4,
    ArchiveAnalystLevel.level3 => 6,
  };

  int get maxCompeting => switch (this) {
    ArchiveAnalystLevel.insufficient => 0,
    ArchiveAnalystLevel.level1 => 3,
    ArchiveAnalystLevel.level2 => 4,
    ArchiveAnalystLevel.level3 => 5,
  };

  int get maxDebates => switch (this) {
    ArchiveAnalystLevel.insufficient => 0,
    ArchiveAnalystLevel.level1 => 1,
    ArchiveAnalystLevel.level2 => 2,
    ArchiveAnalystLevel.level3 => 3,
  };
}