import 'dart:io';

import 'package:archiveme_mobile/features/activation/first_loop_activation_model.dart';
import 'package:archiveme_mobile/features/activation/first_loop_activation_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<FirstLoopActivationStore> _store(String stamp) async {
  final path = '/tmp/vm_first_loop_store_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  final prefs = await MobilePrefsStore.open(path);
  return FirstLoopActivationStore(prefs);
}

String _stamp() => DateTime.now().microsecondsSinceEpoch.toString();

void main() {
  test('starts empty', () async {
    final store = await _store(_stamp());
    final state = await store.load();
    expect(state.stage, FirstLoopActivationStage.notStarted);
    expect(state.isComplete, isFalse);
  });

  test('marks advance the stage forward', () async {
    final store = await _store(_stamp());
    var state = await store.markOpenedRecord();
    expect(state.stage, FirstLoopActivationStage.openedRecord);
    state = await store.markRecordingStarted();
    expect(state.stage, FirstLoopActivationStage.recordingStarted);
    state = await store.markFirstMomentSaved();
    expect(state.stage, FirstLoopActivationStage.firstMomentSaved);
    expect(state.firstMomentSavedAt, isNotNull);
  });

  test('first save marks firstMomentSaved with timestamps', () async {
    final store = await _store(_stamp());
    await store.markOpenedRecord(at: DateTime(2026, 6, 4, 9));
    final state = await store.markFirstMomentSaved(
      at: DateTime(2026, 6, 4, 9, 0, 30),
    );
    expect(state.stage, FirstLoopActivationStage.firstMomentSaved);
    expect(state.secondsToFirstSave, 30);
  });

  test('first pattern shown stores title', () async {
    final store = await _store(_stamp());
    await store.markFirstMomentSaved();
    final state = await store.markFirstPatternShown('saying yes');
    expect(state.stage, FirstLoopActivationStage.firstPatternShown);
    expect(state.firstPatternTitle, 'saying yes');
  });

  test('loop ready records chosen check, completion and is complete', () async {
    final store = await _store(_stamp());
    await store.markOpenedRecord(at: DateTime(2026, 6, 4, 9));
    final state = await store.markLoopReady(
      'saying yes',
      'What happens right before you say yes?',
      at: DateTime(2026, 6, 4, 9, 1),
    );
    expect(state.stage, FirstLoopActivationStage.loopReady);
    expect(state.isComplete, isTrue);
    expect(state.tomorrowQuestion, 'What happens right before you say yes?');
    expect(state.tomorrowCheckChosenAt, isNotNull);
    expect(state.secondsToLoopReady, 60);
  });

  test('stage cannot regress', () async {
    final store = await _store(_stamp());
    await store.markLoopReady('t', 'q');
    // A later "opened record" must not drag the user back to the start.
    final state = await store.markOpenedRecord();
    expect(state.stage, FirstLoopActivationStage.loopReady);
    expect(state.isComplete, isTrue);
  });

  test('clear resets to empty', () async {
    final store = await _store(_stamp());
    await store.markLoopReady('t', 'q');
    await store.clear();
    final state = await store.load();
    expect(state.stage, FirstLoopActivationStage.notStarted);
  });

  test('dropoff point reflects where the user stalled', () async {
    final store = await _store(_stamp());
    var state = await store.markRecordingStarted();
    expect(state.dropoffPoint, FirstLoopDropoffPoint.saveFriction);
    state = await store.markFirstPatternShown('t');
    expect(state.dropoffPoint, FirstLoopDropoffPoint.questionIssue);
    state = await store.markLoopReady('t', 'q');
    expect(state.dropoffPoint, FirstLoopDropoffPoint.none);
  });
}