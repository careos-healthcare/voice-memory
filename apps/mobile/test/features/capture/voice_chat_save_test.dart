import 'dart:async';

import 'package:archiveme_mobile/features/capture/controllers/live_voice_session.dart';
import 'package:archiveme_mobile/features/capture/services/entry_save_pipeline.dart';
import 'package:archiveme_mobile/features/capture/views/voice_chat_view.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_flow_panels.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _reflection = Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

void main() {
  test('the saved transcript keeps only the person\'s words', () {
    final askedAt = DateTime.utc(2026, 9, 26, 12);
    final entry = JournalEntry(
      id: 'entry-1',
      createdAt: askedAt,
      transcript: 'should be replaced',
      durationSeconds: 12,
      reflection: _reflection,
    );
    final saved = EntrySavePipeline.consolidate(
      entry: entry,
      lines: [
        VoiceChatLine(
          role: VoiceChatRole.user,
          text: 'the river',
          at: askedAt,
        ),
        VoiceChatLine(
          role: VoiceChatRole.user,
          text: 'still talking',
          at: askedAt,
          partial: true,
        ),
        VoiceChatLine(
          role: VoiceChatRole.app,
          text: 'What stood out just then?',
          at: askedAt,
        ),
        VoiceChatLine(
          role: VoiceChatRole.user,
          text: 'it was cold',
          at: askedAt.add(const Duration(seconds: 4)),
        ),
      ],
    );

    expect(saved.transcript, 'the river it was cold');
    expect(saved.transcript.contains('What stood out'), isFalse);
    expect(saved.aiQuestions, hasLength(1));
    expect(saved.aiQuestions.single.text, 'What stood out just then?');
    expect(saved.aiQuestions.single.afterUserChars, 'the river'.length);

    final loaded = JournalEntry.fromJson(saved.toJson());
    expect(loaded.transcript, saved.transcript);
    expect(loaded.aiQuestions, saved.aiQuestions);

    final played = savedConversationLines(
      transcript: loaded.transcript,
      questions: loaded.aiQuestions,
    );
    expect(played.map((line) => line.text).toList(), [
      'the river',
      'What stood out just then?',
      'it was cold',
    ]);
    expect(played[1].role, VoiceChatRole.app);
  });

  testWidgets('app questions are visually distinct from your words', (tester) async {
    final at = DateTime.utc(2026, 9, 26);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: VoiceChatView(
            lines: [
              VoiceChatLine(
                role: VoiceChatRole.user,
                text: 'the river',
                at: at,
              ),
              VoiceChatLine(
                role: VoiceChatRole.app,
                text: 'What stood out just then?',
                at: at,
              ),
            ],
          ),
        ),
      ),
    );

    final user = tester.widget<Text>(find.byKey(const Key('voice_chat_user_0')));
    final app = tester.widget<Text>(find.text('What stood out just then?'));
    expect(user.style?.fontStyle, isNot(FontStyle.italic));
    expect(app.style?.fontStyle, FontStyle.italic);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byKey(const Key('voice_chat_app_1')), findsOneWidget);
  });

  testWidgets('the recording screen shows the live bubbles', (tester) async {
    final at = DateTime.utc(2026, 9, 26);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaptureRecordingPanel(
            duration: const Duration(seconds: 4),
            levels: const [0.2],
            chatLines: [
              VoiceChatLine(
                role: VoiceChatRole.user,
                text: 'the river',
                at: at,
              ),
              VoiceChatLine(
                role: VoiceChatRole.app,
                text: 'What stood out just then?',
                at: at,
              ),
            ],
            onStop: () {},
            onCancel: () {},
            onPause: () {},
            onResume: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('capture_voice_chat')), findsOneWidget);
    expect(find.text('the river'), findsOneWidget);
    expect(find.text('What stood out just then?'), findsOneWidget);
    expect(find.byKey(const Key('capture_draft_text')), findsNothing);
  });

  test('a reflect turn keeps the user line and the question apart', () async {
    _HoldTimer? pending;
    final session = ReflectWithMeSession(
      questions: ReflectQuestionGenerator(),
      readAloud: ReadAloudService(speakText: (_) async {}),
      clock: () => DateTime.utc(2026, 9, 26, 12),
      startTimer: (_, callback) {
        final timer = _HoldTimer(callback);
        pending = timer;
        return timer;
      },
    );
    session.notePartial('the river');
    session.onSpeechStart();
    session.noteLevel(-50);
    pending!.fire();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await session.close();

    final saved = EntrySavePipeline.consolidate(
      entry: JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026, 9, 26),
        transcript: '',
        durationSeconds: 3,
        reflection: _reflection,
      ),
      lines: session.lines,
    );
    expect(saved.transcript, 'the river');
    expect(saved.aiQuestions.single.text, 'What stood out just then?');
    expect(saved.transcript.contains('What stood out'), isFalse);
  });
}

class _HoldTimer implements Timer {
  _HoldTimer(this._onFire);

  final void Function() _onFire;
  var _cancelled = false;

  void fire() {
    if (_cancelled) return;
    _cancelled = true;
    _onFire();
  }

  @override
  void cancel() => _cancelled = true;

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}
