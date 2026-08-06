import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/curiosity_hook_engine.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import '../../support/test_storage_sandbox.dart';

const _anchor = 'said yes again';

final _forbiddenLoopPatterns = [
  RegExp(r'showed up again.*showed up again', caseSensitive: false),
  RegExp(r'come back when.*come back when', caseSensitive: false),
  RegExp(r'what got in the way.*what got in the way', caseSensitive: false),
  RegExp(r'what felt different.*what felt different', caseSensitive: false),
];

CuriosityHookEntryMetadata _metadata({
  required String entryId,
  bool hasBlockers = false,
  String? emotionalTone,
  int entryCount = 2,
  List<String> extractedAnchors = const [_anchor],
}) {
  return CuriosityHookEntryMetadata(
    entryId: entryId,
    createdAt: DateTime.utc(2026, 6, 12, 12),
    extractedAnchors: extractedAnchors,
    emotionalTone: emotionalTone,
    hasBlockers: hasBlockers,
    entryCount: entryCount,
  );
}

CuriosityHook _requireHook(CuriosityHook? hook) {
  expect(hook, isNotNull);
  return hook!;
}

void _expectPromptAvoidsForbiddenLoops(String prompt) {
  expect(prompt.trim(), isNotEmpty);
  for (final pattern in _forbiddenLoopPatterns) {
    expect(
      pattern.hasMatch(prompt),
      isFalse,
      reason: 'prompt must not contain cyclic phrase: "$prompt"',
    );
  }
  expect(
    RegExp(
      '"$RegExp.escape(_anchor)".*"$RegExp.escape(_anchor)"',
    ).hasMatch(prompt),
    isFalse,
    reason: 'prompt must not repeat the anchor twice: "$prompt"',
  );
}

CuriosityHook _hook({
  required String id,
  required DateTime createdAt,
  required bool isConsumed,
  CuriosityHookType hookType = CuriosityHookType.anchorFollowUp,
  String dynamicPrompt =
      'Next time "$_anchor" comes up, what do you want to notice first?',
}) {
  return CuriosityHook(
    id: id,
    entryId: 'entry_$id',
    createdAt: createdAt,
    primaryAnchor: _anchor,
    hookType: hookType,
    dynamicPrompt: dynamicPrompt,
    isConsumed: isConsumed,
  );
}

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await LocalCuriosityHookRepository.resetForTest(AppServices.instance.prefs);
  });


  tearDown(() => sandbox.dispose());
  group('CuriosityHookEngine', () {
    test('test_notification_payload_generation_excludes_forbidden_loops', () {
      final prompts = <String>[];
      var recentTypes = <CuriosityHookType>[];

      for (var i = 0; i < 4; i++) {
        final hook = _requireHook(
          CuriosityHookEngine.build(
            metadata: _metadata(
              entryId: 'entry_$i',
              hasBlockers: i.isEven,
              emotionalTone: i.isOdd ? 'hopeful lighter' : 'thoughtful',
              entryCount: 4,
            ),
            recentHookTypes: recentTypes,
            now: DateTime.utc(2026, 6, 12, 12, i),
          ),
        );

        _expectPromptAvoidsForbiddenLoops(hook.dynamicPrompt);
        expect(prompts, isNot(contains(hook.dynamicPrompt)));
        prompts.add(hook.dynamicPrompt);
        recentTypes = [hook.hookType, ...recentTypes];
      }

      for (final hookType in CuriosityHookType.values) {
        final hook = _requireHook(
          CuriosityHookEngine.build(
            metadata: _metadata(
              entryId: 'typed_${hookType.name}',
              hasBlockers: hookType == CuriosityHookType.blocker,
              emotionalTone: hookType == CuriosityHookType.momentum
                  ? 'hopeful lighter'
                  : 'thoughtful',
              entryCount: hookType == CuriosityHookType.returnWatch ? 4 : 2,
            ),
            recentHookTypes: const [],
          ),
        );
        _expectPromptAvoidsForbiddenLoops(hook.dynamicPrompt);
      }
    });

    test('test_hook_generation_prioritizes_blockers', () {
      final hook = _requireHook(
        CuriosityHookEngine.build(
          metadata: _metadata(
            entryId: 'blocked_entry',
            hasBlockers: true,
            emotionalTone: 'hopeful lighter',
            entryCount: 4,
          ),
        ),
      );

      expect(hook.hookType, CuriosityHookType.blocker);
      expect(hook.dynamicPrompt.toLowerCase(), contains('what got in the way'));
      expect(hook.dynamicPrompt, contains(_anchor));
      _expectPromptAvoidsForbiddenLoops(hook.dynamicPrompt);
    });

    test('test_hook_generation_captures_momentum', () {
      final hook = _requireHook(
        CuriosityHookEngine.build(
          metadata: _metadata(
            entryId: 'momentum_entry',
            hasBlockers: false,
            emotionalTone: 'hopeful lighter',
            entryCount: 2,
          ),
        ),
      );

      expect(hook.hookType, CuriosityHookType.momentum);
      expect(hook.dynamicPrompt.toLowerCase(), contains('what felt different'));
      expect(hook.dynamicPrompt, contains(_anchor));
      _expectPromptAvoidsForbiddenLoops(hook.dynamicPrompt);
    });
  });

  group('LocalCuriosityHookRepository', () {
    test('test_repository_returns_freshest_unconsumed_hook', () async {
      final repo = LocalCuriosityHookRepository.instance();
      final oldest = _hook(
        id: 'oldest',
        createdAt: DateTime.utc(2026, 6, 10),
        isConsumed: true,
      );
      final middle = _hook(
        id: 'middle',
        createdAt: DateTime.utc(2026, 6, 11),
        isConsumed: false,
        hookType: CuriosityHookType.momentum,
        dynamicPrompt:
            'You named "$_anchor" — what felt different about it this time?',
      );
      final freshest = _hook(
        id: 'freshest',
        createdAt: DateTime.utc(2026, 6, 12),
        isConsumed: false,
        hookType: CuriosityHookType.blocker,
        dynamicPrompt:
            'Before "$_anchor" showed up again, what got in the way?',
      );

      await repo.saveHook(oldest);
      await repo.saveHook(middle);
      await repo.saveHook(freshest);

      expect((await repo.fetchLatestUnconsumed())?.id, freshest.id);

      await repo.markConsumed(freshest.id);
      expect((await repo.fetchLatestUnconsumed())?.id, middle.id);

      await repo.markConsumed(middle.id);
      expect(await repo.fetchLatestUnconsumed(), isNull);
    });
  });
}
