import 'package:archiveme_mobile/features/capture_flow/routine/routine_kind_resolver.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/routine/routine_anchor_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutineKindResolver', () {
    test('prefers explicit routine override', () {
      expect(
        RoutineKindResolver.resolve(
          explicit: JournalRoutineKind.evening,
          now: DateTime(2026, 8, 10, 8),
        ),
        JournalRoutineKind.evening,
      );
    });

    test('maps morning anchor to morning routine', () {
      expect(
        RoutineKindResolver.resolve(
          routineAnchor: const RoutineAnchor(type: RoutineAnchorType.morning),
          now: DateTime(2026, 8, 10, 21),
        ),
        JournalRoutineKind.morning,
      );
    });

    test('infers evening from clock', () {
      expect(
        RoutineKindResolver.resolve(now: DateTime(2026, 8, 10, 19, 30)),
        JournalRoutineKind.evening,
      );
    });

    test('defaults midday to morning', () {
      expect(
        RoutineKindResolver.resolve(now: DateTime(2026, 8, 10, 14)),
        JournalRoutineKind.morning,
      );
    });
  });
}
