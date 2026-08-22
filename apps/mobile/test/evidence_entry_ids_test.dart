import 'package:archiveme_mobile/features/archive_evidence/evidence_entry_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvidenceEntryIds.merge', () {
    test('de-duplicates and caps', () {
      expect(
        EvidenceEntryIds.merge([
          ['a', 'b'],
          ['b', 'c'],
        ]),
        ['a', 'b', 'c'],
      );
    });

    test('skips blank and non-string legacy values', () {
      expect(
        EvidenceEntryIds.merge([
          ['  id-1  ', '', 'id-1'],
          [42, null, 'id-2'],
        ]),
        ['id-1', 'id-2'],
      );
    });
  });
}