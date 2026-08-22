import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CognitiveBiomarkers', () {
    test('round trips through json', () {
      const biomarkers = CognitiveBiomarkers(
        lexicalDiversity: 0.72,
        cohesionDrift: 0.18,
        emotionalVolatility: 0.41,
      );

      final restored = CognitiveBiomarkers.fromJson(biomarkers.toJson());

      expect(restored, biomarkers);
    });

    test('copyWith replaces selected values', () {
      const original = CognitiveBiomarkers(
        lexicalDiversity: 0.72,
        cohesionDrift: 0.18,
        emotionalVolatility: 0.41,
      );

      final updated = original.copyWith(cohesionDrift: 0.25);

      expect(updated.lexicalDiversity, 0.72);
      expect(updated.cohesionDrift, 0.25);
      expect(updated.emotionalVolatility, 0.41);
      expect(updated == original, isFalse);
    });

    test('fromJson returns null for missing or invalid payloads', () {
      expect(CognitiveBiomarkers.fromJson(null), isNull);
      expect(CognitiveBiomarkers.fromJson({}), isNull);
      expect(
        CognitiveBiomarkers.fromJson({
          'lexicalDiversity': 0.5,
          'cohesionDrift': double.nan,
          'emotionalVolatility': 0.2,
        }),
        isNull,
      );
    });

    test('equality compares all biomarker scores', () {
      const left = CognitiveBiomarkers(
        lexicalDiversity: 0.5,
        cohesionDrift: 0.2,
        emotionalVolatility: 0.3,
      );
      const right = CognitiveBiomarkers(
        lexicalDiversity: 0.5,
        cohesionDrift: 0.2,
        emotionalVolatility: 0.3,
      );
      const different = CognitiveBiomarkers(
        lexicalDiversity: 0.5,
        cohesionDrift: 0.2,
        emotionalVolatility: 0.31,
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
      expect(left == different, isFalse);
    });
  });
}