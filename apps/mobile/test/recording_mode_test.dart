import 'package:archiveme_mobile/core/config/live_conversation_feature_flags.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/recording/recording_mode.dart';
import 'package:archiveme_mobile/features/recording/widgets/recording_mode_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecordingMode', () {
    test('passive journaling does not use live conversation', () {
      expect(
        RecordingMode.passiveJournaling.usesLiveConversation,
        isFalse,
      );
    });

    test('conversational journaling uses live conversation', () {
      expect(
        RecordingMode.conversationalJournaling.usesLiveConversation,
        isTrue,
      );
    });
  });

  group('RecordingModeToggle', () {
    testWidgets('hidden when live conversation flag is off', (tester) async {
      LiveConversationFeatureFlags.debugOverride = false;
      addTearDown(() => LiveConversationFeatureFlags.debugOverride = null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingModeToggle(
              mode: RecordingMode.passiveJournaling,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('recording_mode_toggle')), findsNothing);
    });

    testWidgets('visible when live conversation flag is on', (tester) async {
      LiveConversationFeatureFlags.debugOverride = true;
      addTearDown(() => LiveConversationFeatureFlags.debugOverride = null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingModeToggle(
              mode: RecordingMode.passiveJournaling,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('recording_mode_toggle')), findsOneWidget);
      expect(find.text('Reflective mode'), findsOneWidget);
      expect(find.text('Live conversation'), findsOneWidget);
    });
  });

  test('V1 liveVoice capability follows feature flag default', () {
    LiveConversationFeatureFlags.debugOverride = false;
    addTearDown(() => LiveConversationFeatureFlags.debugOverride = null);
    expect(V1CapabilityRegistry.liveVoice, isFalse);
  });
}