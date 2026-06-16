import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/first_loop_activation_model.dart';
import 'package:voicememory_mobile/features/activation/first_loop_activation_store.dart';
import 'package:voicememory_mobile/features/activation/return_day_friction_model.dart';
import 'package:voicememory_mobile/features/activation/return_day_friction_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:voicememory_mobile/features/trial/trial_reset_service.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_trialreset_journal_$stamp.json',
    prefsPath: '/tmp/vm_trialreset_prefs_$stamp.json',
  );
}

void main() {
  tearDown(CheckInReminderService.resetBackendForTest);

  test(
    'resetForNewParticipant clears activation, loop, friction and reminders',
    () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      final prefs = AppServices.instance.prefs;

      // Seed state across the loop.
      await ActivationEventsStore(prefs).write(
        const ActivationEventCounts(
          firstReflectionSaved: 3,
          tomorrowCheckInCreated: 2,
          returnDayLoopClosed: 1,
        ),
      );
      await FirstLoopActivationStore(prefs).markFirstMomentSaved();
      await FirstLoopActivationStore(
        prefs,
      ).markLoopReady('Pattern', 'Did this show up again?');
      await ReturnDayFrictionStore(prefs).markDueShown('cid-1');
      await ReturnDayFrictionStore(
        prefs,
      ).markAnswerSelected('cid-1', 'showed_up');
      await CheckInReminderService.setRemindersEnabled(true);

      // Sanity: state is actually seeded before reset.
      expect(
        (await FirstLoopActivationStore(prefs).load()).stage,
        FirstLoopActivationStage.loopReady,
      );
      expect(
        (await ReturnDayFrictionStore(prefs).load()).stage,
        ReturnDayFrictionStage.answerSelected,
      );
      expect(await CheckInReminderService.remindersEnabled(), isTrue);

      // Act.
      await const TrialResetService().resetForNewParticipant();

      // Everything is back to a clean trial baseline.
      final events = await ActivationEventsStore(prefs).read();
      expect(events.firstReflectionSaved, 0);
      expect(events.tomorrowCheckInCreated, 0);
      expect(events.returnDayLoopClosed, 0);

      final firstLoop = await FirstLoopActivationStore(prefs).load();
      expect(firstLoop.stage, FirstLoopActivationStage.notStarted);

      final friction = await ReturnDayFrictionStore(prefs).load();
      expect(friction.stage, ReturnDayFrictionStage.notDue);
      expect(friction.checkInId, isNull);

      expect(await CheckInReminderService.remindersEnabled(), isFalse);
    },
  );
}
