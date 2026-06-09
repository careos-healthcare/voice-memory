import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/input_quality/input_quality_engine.dart';
import 'package:voicememory_mobile/features/input_quality/input_quality_model.dart';
import 'package:voicememory_mobile/features/input_quality/input_quality_store.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_input_quality_journal_$stamp.json',
    prefsPath: '/tmp/vm_input_quality_prefs_$stamp.json',
  );
}

void main() {
  test('records the latest assessment', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = InputQualityStore(AppServices.instance.prefs);

    final weak = assessReflectionQuality('Today was stressful.');
    await store.recordAssessment(weak);

    final state = await store.read();
    expect(state.lastQualityLevel, weak.level);
    expect(state.lastScore, weak.score);
    expect(state.lastIssues, contains(InputQualityIssue.tooGeneral));
    expect(state.assessmentCount, 1);
    expect(state.averageInputQualityScore, weak.score);
  });

  test('average score blends multiple assessments', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = InputQualityStore(AppServices.instance.prefs);

    final weak = assessReflectionQuality('Today was stressful.');
    final strong =
        assessReflectionQuality('I said yes before checking what I needed.');
    await store.recordAssessment(weak);
    await store.recordAssessment(strong);

    final state = await store.read();
    expect(state.assessmentCount, 2);
    expect(state.lastQualityLevel, strong.level);
    expect(
      state.averageInputQualityScore,
      closeTo((weak.score + strong.score) / 2, 0.0001),
    );
  });

  test('tracks accepted weak and sharpened counts', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = InputQualityStore(AppServices.instance.prefs);

    await store.recordAcceptedWeak();
    await store.recordSharpened();
    await store.recordSharpened();

    final state = await store.read();
    expect(state.acceptedWeakInputCount, 1);
    expect(state.sharpenedInputCount, 2);
  });
}
