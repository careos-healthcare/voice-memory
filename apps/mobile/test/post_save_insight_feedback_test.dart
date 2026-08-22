import 'package:archiveme_mobile/features/post_save_insight/selected_signal_coordinator.dart';
import 'package:archiveme_mobile/features/post_save_insight/signal_feedback_coordinator.dart';
import 'package:archiveme_mobile/features/post_save_insight/signal_feedback_model.dart';
import 'package:archiveme_mobile/features/post_save_insight/signal_feedback_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_post_save_feedback_journal_$stamp.json',
    prefsPath: '/tmp/vm_post_save_feedback_prefs_$stamp.json',
  );
}

void main() {
  test('A selection stores feedback', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await SignalFeedbackCoordinator.track(
      action: PostSaveSignalAction.abChoiceA,
      signalId: 'sig_a',
      signalTitle: 'Taking responsibility before asking for help',
      categoryId: 'responsibility',
    );
    await SelectedSignalCoordinator.save(
      title: 'Taking responsibility before asking for help',
      categoryId: 'responsibility',
      strengthLabel: 'Early signal',
      nextPrompt: 'When did you next feel pressure to say yes?',
    );

    final feedback = await SignalFeedbackStore.instance().loadAll();
    expect(
      feedback.any((f) => f.action == PostSaveSignalAction.abChoiceA),
      isTrue,
    );
    final selected = await SelectedSignalCoordinator.loadCurrent();
    expect(selected?.title, contains('responsibility'));
  });

  test('B selection stores feedback', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await SignalFeedbackCoordinator.track(
      action: PostSaveSignalAction.abChoiceB,
      signalId: 'sig_b',
      signalTitle: 'Fear of disappointing someone',
      categoryId: 'relationship',
    );

    final feedback = await SignalFeedbackStore.instance().loadAll();
    expect(
      feedback.any((f) => f.action == PostSaveSignalAction.abChoiceB),
      isTrue,
    );
  });

  test('Neither stores feedback action', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);

    await SignalFeedbackCoordinator.track(
      action: PostSaveSignalAction.abChoiceNeither,
      signalId: 'sig_a',
      signalTitle: 'Taking responsibility before asking for help',
      categoryId: 'responsibility',
    );

    final feedback = await SignalFeedbackStore.instance().loadAll();
    expect(
      feedback.any((f) => f.action == PostSaveSignalAction.abChoiceNeither),
      isTrue,
    );
  });
}