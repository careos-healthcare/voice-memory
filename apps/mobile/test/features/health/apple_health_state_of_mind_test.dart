import 'dart:io';

import 'package:archiveme_mobile/features/health/apple_health_platform.dart';
import 'package:archiveme_mobile/features/health/apple_health_settings_section.dart';
import 'package:archiveme_mobile/features/health/state_of_mind_reader.dart';
import 'package:archiveme_mobile/features/health/state_of_mind_writer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppleHealthPlatform.debugIsIos = null;
    AppleHealthPlatform.debugSupportsStateOfMind = null;
    StateOfMindReader.debugLookup = null;
    StateOfMindReader.clearCache();
    StateOfMindWriter.debugWriteEnabled = null;
    StateOfMindWriter.debugWrite = null;
    StateOfMindWriter.sampleIds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StateOfMindReader.channel, null);
  });

  test('permission is requested only from the settings explanation', () {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (!entity.readAsStringSync().contains('requestAuthorization')) continue;
      hits.add(entity.path.replaceAll('\\', '/'));
    }
    expect(
      hits,
      unorderedEquals([
        'lib/features/health/health_factory.dart',
        'lib/features/health/apple_health_prompt.dart',
      ]),
    );
  });

  test('mood choices map to State of Mind labels and valence', () {
    expect(StateOfMindWriteMap.table, {
      'calm': ('calm', 0.4),
      'grounded': ('calm', 0.4),
      'anxious': ('anxious', -0.5),
      'energetic': ('excited', 0.7),
      'reflective': ('peaceful', 0.3),
      'low': ('sad', -0.6),
    });
  });

  test('writing a mood then clearing it deletes that sample', () async {
    final store = <String, Map<Object?, Object?>>{};
    var permissionRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(StateOfMindReader.channel, (call) async {
          if (call.method == 'requestAuthorization') {
            permissionRequests += 1;
            return true;
          }
          if (call.method == 'writeStateOfMind') {
            final args = Map<Object?, Object?>.from(call.arguments as Map);
            store['sample-1'] = args;
            return 'sample-1';
          }
          if (call.method == 'deleteStateOfMind') {
            store.remove((call.arguments as Map)['uuid']);
            return true;
          }
          return null;
        });

    AppleHealthPlatform.debugIsIos = true;
    StateOfMindWriter.debugWriteEnabled = true;

    expect(
      await StateOfMindWriter.writeJournalMood('Calm', entryId: 'entry-1'),
      isTrue,
    );
    expect(StateOfMindWriter.sampleIds['entry-1'], 'sample-1');
    expect(store['sample-1']?['label'], 'calm');
    expect(store['sample-1']?['valence'], 0.4);
    expect(permissionRequests, 0);

    expect(
      await StateOfMindWriter.writeJournalMood('', entryId: 'entry-1'),
      isTrue,
    );
    expect(store.containsKey('sample-1'), isFalse);
    expect(StateOfMindWriter.sampleIds.containsKey('entry-1'), isFalse);
    expect(permissionRequests, 0);
  });

  test('a day of State of Mind is read once and cached', () async {
    var calls = 0;
    StateOfMindReader.debugLookup = (day) async {
      calls += 1;
      return 'peaceful';
    };
    final morning = DateTime(2026, 9, 26, 8);
    final evening = DateTime(2026, 9, 26, 20);
    expect(await StateOfMindReader.forDay(morning), 'peaceful');
    expect(await StateOfMindReader.forDay(evening), 'peaceful');
    expect(calls, 1);
  });

  testWidgets('the Apple Health row is hidden below iOS 18', (tester) async {
    AppleHealthPlatform.debugIsIos = true;
    AppleHealthPlatform.debugSupportsStateOfMind = false;
    await tester.pumpWidget(_section());
    expect(find.byKey(const Key('settings_health_mood_sync')), findsNothing);
    expect(find.text('Apple Health'), findsNothing);

    AppleHealthPlatform.debugSupportsStateOfMind = true;
    await tester.pumpWidget(_section());
    expect(find.text('Apple Health'), findsOneWidget);
    expect(find.text('Save my moods to Apple Health'), findsOneWidget);
  });

  testWidgets('a revoked Health permission shows the toggle off', (
    tester,
  ) async {
    AppleHealthPlatform.debugSupportsStateOfMind = true;
    await tester.pumpWidget(_section(revoked: true));
    final read = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings_health_mood_sync')),
    );
    expect(read.value, isFalse);
    expect(find.byKey(const Key('settings_health_settings_link')), findsOneWidget);
  });
}

Widget _section({bool revoked = false}) {
  return MaterialApp(
    home: Scaffold(
      body: AppleHealthSettingsSection(
        readEnabled: true,
        writeEnabled: true,
        revoked: revoked,
        onRead: (_) {},
        onWrite: (_) {},
        onOpenSettings: () {},
      ),
    ),
  );
}
