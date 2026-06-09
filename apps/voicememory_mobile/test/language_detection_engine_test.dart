import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/language/language_detection_engine.dart';
import 'package:voicememory_mobile/features/language/language_model.dart';

void main() {
  test('Gujarati script detects gu', () {
    final result = detectReflectionLanguage('આજે કામ પર દબાણ લાગ્યું.');
    expect(result.code, 'gu');
    expect(result.isSupported, isTrue);
    expect(result.confidence, greaterThan(0.8));
    expect(result.source, LanguageSource.heuristic);
  });

  test('Devanagari script detects hi', () {
    final result = detectReflectionLanguage('आज काम पर दबाव महसूस हुआ।');
    expect(result.code, 'hi');
    expect(result.isSupported, isTrue);
    expect(result.confidence, greaterThan(0.8));
  });

  test('Spanish word set detects es', () {
    final result =
        detectReflectionLanguage('Hoy estoy cansado porque trabajo mucho.');
    expect(result.code, 'es');
    expect(result.isSupported, isTrue);
    expect(result.confidence, greaterThanOrEqualTo(0.5));
  });

  test('French word set detects fr', () {
    final result = detectReflectionLanguage(
      "Je suis fatigué aujourd'hui parce que le travail.",
    );
    expect(result.code, 'fr');
    expect(result.isSupported, isTrue);
  });

  test('short unclear text falls back to en', () {
    final result = detectReflectionLanguage('ok');
    expect(result.code, 'en');
    expect(result.isLowConfidence, isTrue);
  });

  test('empty text falls back to en', () {
    final result = detectReflectionLanguage('   ');
    expect(result.code, 'en');
    expect(result.source, LanguageSource.fallback);
  });

  test('clear English text stays en with usable confidence', () {
    final result = detectReflectionLanguage(
      'I said yes before checking what I needed today.',
    );
    expect(result.code, 'en');
    expect(result.isNonEnglish, isFalse);
  });
}
