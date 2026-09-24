import 'package:archiveme_mobile/features/audio/dual_mode_audio_engine.dart';
import 'package:archiveme_mobile/features/reflection/guided_reflection_call_screen.dart';
import 'package:archiveme_mobile/features/reflection/proactive_reflection_scheduler.dart';
import 'package:archiveme_mobile/features/reflection/reflection_prompts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 12);

  test('mature goals rewrite the evening and sunday titles', () async {
    final backend = _RecordingBackend();
    final scheduler = ProactiveReflectionScheduler(
      notificationsEnabled: true,
      backend: backend,
      clock: () => now,
    );

    final planned = await scheduler.schedule(
      triggers: const [
        ReflectionGraphTrigger(
          name: 'project milestone',
          category: 'goals',
          mature: true,
        ),
      ],
    );

    expect(planned, hasLength(2));
    expect(planned.first.title, 'How did your project milestone go today?');
    expect(planned.first.matchComponents, 'time');
    expect(planned.first.scheduledDate, DateTime(2026, 9, 23, 20));
    expect(planned.last.title, 'How did your project milestone go this week?');
    expect(planned.last.matchComponents, 'dayOfWeekAndTime');
    expect(planned.last.scheduledDate.weekday, DateTime.sunday);
    expect(planned.last.scheduledDate, DateTime(2026, 9, 27, 18));
    expect(backend.items.map((item) => item.payload), [
      'reflection:evening_check_in',
      'reflection:sunday_review',
    ]);
  });

  test('default titles stay when no goal is mature', () async {
    final backend = _RecordingBackend();
    final scheduler = ProactiveReflectionScheduler(
      notificationsEnabled: false,
      backend: backend,
      clock: () => now,
    );

    final planned = await scheduler.schedule(
      triggers: const [
        ReflectionGraphTrigger(
          name: 'project milestone',
          category: 'goals',
          mature: false,
        ),
      ],
    );

    expect(planned.first.title, 'Evening Check-in');
    expect(planned.last.title, 'Sunday Review');
    expect(backend.items, isEmpty);
    expect(scheduler.pending, planned);
  });

  test('graph rows marked mature become prompt triggers', () async {
    final scheduler = ProactiveReflectionScheduler(
      notificationsEnabled: false,
      clock: () => DateTime(2026, 9, 23, 21),
    );
    final planned = await scheduler.scheduleFromGraph((sql, args) async {
      expect(sql, contains('FROM entities'));
      expect(args, ['goals', 'mature']);
      return const [
        {
          'name': 'project milestone',
          'category': 'goals',
          'description': 'mature',
        },
        {'name': 'lunch', 'category': 'goals', 'description': 'open'},
      ];
    });

    expect(planned.first.title, 'How did your project milestone go today?');
    expect(planned.first.scheduledDate, DateTime(2026, 9, 24, 20));
  });

  testWidgets('a notification payload opens the reflection call', (
    tester,
  ) async {
    const payload = 'reflection:evening_check_in';
    expect(ReflectionCallLaunch.matches(payload), isTrue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dualModeAudioEngineProvider.overrideWith(_ScriptedEngine.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => ReflectionCallLaunch.open(
                  context,
                  title: 'Evening Check-in',
                ),
                child: const Text('Open prompt'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open prompt'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('guided_reflection_call')), findsOneWidget);
    expect(find.text('Evening Check-in'), findsOneWidget);
    expect(
      find.byKey(const Key('reflection_listening_visualizer')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('reflection_view_transcript')));
    await tester.pump();
    expect(find.text('The milestone landed.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reflection_save')));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reflection_dismiss')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('guided_reflection_call')), findsNothing);
  });
}

class _RecordingBackend implements ReflectionNotificationBackend {
  final items = <ScheduledReflectionNotification>[];

  @override
  Future<void> cancelPending() async {}

  @override
  Future<void> schedule(ScheduledReflectionNotification notification) async {
    items.add(notification);
  }
}

class _ScriptedEngine extends DualModeAudioEngine {
  @override
  Future<DualModeAudioSnapshot> build() async => const DualModeAudioSnapshot();

  @override
  Future<void> selectMode(DualAudioMode mode) async {
    state = AsyncData(DualModeAudioSnapshot(mode: mode));
  }

  @override
  Future<void> start() async {
    state = const AsyncData(
      DualModeAudioSnapshot(
        mode: DualAudioMode.interactive,
        recording: true,
        partialTranscript: 'The milestone landed.',
      ),
    );
  }
}
