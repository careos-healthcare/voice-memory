import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/curiosity_notification_launch_controller.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/curiosity_notification_scheduler.dart';
import 'package:voicememory_mobile/services/app_services.dart';

class _FakeRepository implements CuriosityHookRepository {
  _FakeRepository(this.hooks);

  final Map<String, CuriosityHook> hooks;

  @override
  Future<CuriosityHook?> fetchById(String hookId) async => hooks[hookId];

  @override
  Future<CuriosityHook?> fetchLatestUnconsumed() async {
    for (final hook in hooks.values) {
      if (!hook.isConsumed) return hook;
    }
    return null;
  }

  @override
  Future<List<CuriosityHook>> loadAll() async => hooks.values.toList();

  @override
  Future<List<CuriosityHookType>> recentHookTypes({int limit = 4}) async =>
      const [];

  @override
  Future<void> markConsumed(String hookId) async {}

  @override
  Future<void> saveHook(CuriosityHook hook) async {
    hooks[hook.id] = hook;
  }
}

class _FakeScheduler extends CuriosityNotificationScheduler {
  _FakeScheduler({this.coldStartHookId});

  final String? coldStartHookId;
  String? lastTapHookId;

  @override
  Future<void> initialize() async {}

  @override
  bool get isAvailable => true;

  @override
  Future<String?> readColdStartHookId() async => coldStartHookId;

  void simulateTap(String hookId) {
    onTapHookId?.call(hookId);
  }
}

CuriosityHook _hook({required String id, bool consumed = false}) =>
    CuriosityHook(
      id: id,
      entryId: 'entry_$id',
      createdAt: DateTime.utc(2026, 6, 11, 12),
      primaryAnchor: 'said yes again',
      hookType: CuriosityHookType.blocker,
      dynamicPrompt:
          'Before "said yes again" showed up again, what got in the way?',
      isConsumed: consumed,
    );

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_curiosity_launch_journal_$stamp.json',
    prefsPath: '/tmp/vm_curiosity_launch_prefs_$stamp.json',
    skipRevenueCat: true,
  );
  CuriosityNotificationLaunchController.resetForTest();
  CuriosityNotificationScheduler.resetForTest();
}

void main() {
  setUp(() async {
    await _reset('${DateTime.now().microsecondsSinceEpoch}');
  });

  group('CuriosityNotificationLaunchController', () {
    setUp(() {
      CuriosityNotificationLaunchController.navigateOverrideForTest = (_) =>
          false;
    });

    test('queues valid unconsumed hook from tap payload id', () async {
      final repo = _FakeRepository({'hook_1': _hook(id: 'hook_1')});

      await CuriosityNotificationLaunchController.handleHookIdTap(
        'hook_1',
        repository: repo,
      );

      expect(CuriosityNotificationLaunchController.hasPendingHook, isTrue);
      expect(
        CuriosityNotificationLaunchController.takePendingHook()?.id,
        'hook_1',
      );
      expect(CuriosityNotificationLaunchController.hasPendingHook, isFalse);
    });

    test('ignores missing and consumed hooks', () async {
      final repo = _FakeRepository({
        'consumed': _hook(id: 'consumed', consumed: true),
      });

      await CuriosityNotificationLaunchController.handleHookIdTap(
        'missing',
        repository: repo,
      );
      expect(CuriosityNotificationLaunchController.hasPendingHook, isFalse);

      await CuriosityNotificationLaunchController.handleHookIdTap(
        'consumed',
        repository: repo,
      );
      expect(CuriosityNotificationLaunchController.hasPendingHook, isFalse);
    });

    test('processes cold start hook id during ensureInitialized', () async {
      final repo = _FakeRepository({'cold_hook': _hook(id: 'cold_hook')});
      final scheduler = _FakeScheduler(coldStartHookId: 'cold_hook');

      await CuriosityNotificationLaunchController.ensureInitialized(
        scheduler: scheduler,
        repository: repo,
      );

      expect(CuriosityNotificationLaunchController.hasPendingHook, isTrue);
      expect(
        CuriosityNotificationLaunchController.takePendingHook()?.id,
        'cold_hook',
      );
    });

    test('wires scheduler tap callback to hook resolution', () async {
      final repo = _FakeRepository({'tap_hook': _hook(id: 'tap_hook')});
      final scheduler = _FakeScheduler();

      await CuriosityNotificationLaunchController.ensureInitialized(
        scheduler: scheduler,
        repository: repo,
      );

      scheduler.simulateTap('tap_hook');

      await pumpEventQueue();

      expect(CuriosityNotificationLaunchController.hasPendingHook, isTrue);
      expect(
        CuriosityNotificationLaunchController.takePendingHook()?.id,
        'tap_hook',
      );
    });
  });
}
