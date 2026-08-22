import 'package:archiveme_mobile/record/quick_text_capture_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveFocusedRecordTypeEntry', () {
    test('plain and string extras use focused layout', () {
      expect(resolveFocusedRecordTypeEntry(null), isTrue);
      expect(resolveFocusedRecordTypeEntry('Today I noticed…'), isTrue);
    });

    test('voice fallback and capture modes keep legacy layout', () {
      expect(
        resolveFocusedRecordTypeEntry(<String, Object?>{'entryId': 'e1'}),
        isFalse,
      );
      expect(
        resolveFocusedRecordTypeEntry(<String, Object?>{
          'captureModeId': 'something_happened',
        }),
        isFalse,
      );
      expect(
        resolveFocusedRecordTypeEntry(<String, Object?>{
          'showFirstUseWordingHelper': true,
        }),
        isFalse,
      );
    });
  });
}