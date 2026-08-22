import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/router/capture_routine_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('capture_routine_route', () {
    test('parses routine query param from record uri', () {
      expect(
        journalRoutineKindFromUri(Uri.parse('/record?routine=evening')),
        JournalRoutineKind.evening,
      );
    });

    test('parses routine notification payload', () {
      expect(
        journalRoutineKindFromNotificationPayload('routine:morning'),
        JournalRoutineKind.morning,
      );
    });

    test('builds record path with routine query', () {
      expect(
        captureRecordPath(routine: JournalRoutineKind.evening),
        '/record?routine=evening',
      );
    });
  });
}
