import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_copy.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_entries.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Safe demo summary built only from in-memory sample archive entries.
class DemoSharePack {
  const DemoSharePack({
    required this.plainText,
    required this.workMomentCount,
    required this.homeMomentCount,
  });

  final String plainText;
  final int workMomentCount;
  final int homeMomentCount;
}

/// Deterministic demo share/export — sample data only, never real journal entries.
abstract final class DemoSharePackEngine {
  DemoSharePackEngine._();

  static DemoSharePack build({DateTime? now}) {
    final entries = SampleArchiveEntries.build(now: now);
    assert(
      entries.every(SampleArchiveMode.isSampleEntry),
      'demo share must use sample entries only',
    );
    return _buildFromSampleEntries(entries);
  }

  static DemoSharePack _buildFromSampleEntries(List<JournalEntry> entries) {
    final realEntries = entries.where(SampleArchiveMode.isSampleEntry).toList();
    final map = ArchiveEvidenceMapEngine.build(entries: realEntries);

    var workCount = 0;
    var homeCount = 0;
    for (final row in map.rows) {
      if (row.rowId == CaptureContextTagIds.work) {
        workCount = row.count;
      } else if (row.rowId == CaptureContextTagIds.home) {
        homeCount = row.count;
      }
    }

    final plainText = _plainText(
      workMomentCount: workCount,
      homeMomentCount: homeCount,
    );

    return DemoSharePack(
      plainText: plainText,
      workMomentCount: workCount,
      homeMomentCount: homeCount,
    );
  }

  static String _plainText({
    required int workMomentCount,
    required int homeMomentCount,
  }) {
    final buffer = StringBuffer()
      ..writeln(SampleArchiveCopy.demoShareTitle)
      ..writeln(SampleArchiveCopy.demoShareSubtitle)
      ..writeln()
      ..writeln('• ${SampleArchiveCopy.demoShareBulletOne}')
      ..writeln('• ${SampleArchiveCopy.demoShareBulletTwo}')
      ..writeln('• ${SampleArchiveCopy.demoShareBulletThree}')
      ..writeln()
      ..writeln(SampleArchiveCopy.demoShareEvidenceMapHeading)
      ..writeln(
        SampleArchiveCopy.demoShareEvidenceMapRow('Work', workMomentCount),
      )
      ..writeln(
        SampleArchiveCopy.demoShareEvidenceMapRow('Home', homeMomentCount),
      )
      ..writeln()
      ..writeln(SampleArchiveCopy.demoShareReviewLine)
      ..writeln()
      ..writeln(SampleArchiveCopy.demoSharePrivacyFooter);

    return buffer.toString().trimRight();
  }
}