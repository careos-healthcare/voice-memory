import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/first_loop_activation_coordinator.dart';
import 'package:voicememory_mobile/features/activation/first_loop_activation_model.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_first_loop_coord_journal_$stamp.json',
    prefsPath: '/tmp/vm_first_loop_coord_prefs_$stamp.json',
  );
}

String _stamp() => DateTime.now().microsecondsSinceEpoch.toString();

/// Tracker events are fire-and-forget but their writes are enqueued on the
/// prefs mutex synchronously. Awaiting a serialized write flushes them so the
/// counts are stable to read.
Future<ActivationEventCounts> _events() async {
  await AppServices.instance.prefs.writeBool('__test_settle__', true);
  return ActivationEventsStore(AppServices.instance.prefs).read();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opening record marks openedRecord and tracks once', () async {
    await _reset(_stamp());
    final state = await FirstLoopActivationCoordinator.markOpenedRecord();
    expect(state.stage, FirstLoopActivationStage.openedRecord);
    // Re-opening should not double count.
    await FirstLoopActivationCoordinator.markOpenedRecord();
    final events = await _events();
    expect(events.firstLoopRecordOpened, 1);
  });

  test('first save marks firstMomentSaved and tracks', () async {
    await _reset(_stamp());
    await FirstLoopActivationCoordinator.markOpenedRecord();
    final state = await FirstLoopActivationCoordinator.markFirstMomentSaved();
    expect(state.stage, FirstLoopActivationStage.firstMomentSaved);
    final events = await _events();
    expect(events.firstLoopMomentSaved, 1);
  });

  test('first pattern shown marks firstPatternShown', () async {
    await _reset(_stamp());
    await FirstLoopActivationCoordinator.markFirstMomentSaved();
    final state = await FirstLoopActivationCoordinator.markFirstPatternShown(
      'saying yes',
    );
    expect(state.stage, FirstLoopActivationStage.firstPatternShown);
    expect(state.firstPatternTitle, 'saying yes');
    final events = await _events();
    expect(events.firstLoopPatternShown, 1);
  });

  test('loop ready marks tomorrowCheckChosen and loopReady', () async {
    await _reset(_stamp());
    await FirstLoopActivationCoordinator.markFirstPatternShown('saying yes');
    final state = await FirstLoopActivationCoordinator.markLoopReady(
      patternTitle: 'saying yes',
      tomorrowQuestion: 'What happens right before you say yes?',
    );
    expect(state.stage, FirstLoopActivationStage.loopReady);
    expect(state.isComplete, isTrue);
    final events = await _events();
    expect(events.firstLoopTomorrowCheckChosen, 1);
    expect(events.firstLoopReady, 1);
  });

  test('stage cannot regress through the coordinator', () async {
    await _reset(_stamp());
    await FirstLoopActivationCoordinator.markLoopReady(
      patternTitle: 't',
      tomorrowQuestion: 'q',
    );
    final state = await FirstLoopActivationCoordinator.markRecordingStarted();
    expect(state.stage, FirstLoopActivationStage.loopReady);
  });
}
