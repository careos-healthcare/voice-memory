import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_analyst/archive_analyst_gate.dart';

void main() {
  test('level thresholds', () {
    expect(ArchiveAnalystGate.levelFor(0), ArchiveAnalystLevel.insufficient);
    expect(ArchiveAnalystGate.levelFor(49), ArchiveAnalystLevel.insufficient);
    expect(ArchiveAnalystGate.levelFor(50), ArchiveAnalystLevel.level1);
    expect(ArchiveAnalystGate.levelFor(99), ArchiveAnalystLevel.level1);
    expect(ArchiveAnalystGate.levelFor(100), ArchiveAnalystLevel.level2);
    expect(ArchiveAnalystGate.levelFor(199), ArchiveAnalystLevel.level2);
    expect(ArchiveAnalystGate.levelFor(200), ArchiveAnalystLevel.level3);
  });

  test('canGenerateReport', () {
    expect(ArchiveAnalystGate.canGenerateReport(49), isFalse);
    expect(ArchiveAnalystGate.canGenerateReport(50), isTrue);
  });

  test('reflectionsUntilLevel1', () {
    expect(ArchiveAnalystGate.reflectionsUntilLevel1(40), 10);
    expect(ArchiveAnalystGate.reflectionsUntilLevel1(50), 0);
  });
}
