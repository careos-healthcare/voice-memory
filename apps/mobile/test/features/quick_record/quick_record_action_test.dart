import 'dart:async';

import 'package:archiveme_mobile/features/quick_record/quick_record_action.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(QuickRecordAction.channelName);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == QuickRecordAction.consumePending) return null;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('record deep link is archiveme://action/record', () {
    expect(
      QuickRecordAction.isStartRecordingLink(
        Uri.parse('archiveme://action/record'),
      ),
      isTrue,
    );
    expect(
      QuickRecordAction.isStartRecordingLink(
        Uri.parse('archiveme://quick-capture'),
      ),
      isFalse,
    );
    expect(
      QuickRecordAction.isTranscriptLink(
        Uri.parse('archiveme://action/transcript'),
      ),
      isTrue,
    );
    expect(
      QuickRecordAction.isTranscriptLink(
        Uri.parse('archiveme://action/record'),
      ),
      isFalse,
    );
  });

  test('pending quick action starts recording once', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == QuickRecordAction.consumePending) {
            return QuickRecordAction.startRecording;
          }
          return null;
        });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final links = StreamController<Uri>();
    addTearDown(links.close);
    var starts = 0;
    final notifier = container.read(quickRecordActionProvider.notifier)
      ..duplicateWindow = Duration.zero;

    await notifier.bind(
      channel: channel,
      linkStream: links.stream,
      initialLink: Future<Uri?>.value(),
      startRecording: () async {
        starts++;
      },
    );

    expect(starts, 1);

    links.add(Uri.parse('archiveme://action/record'));
    await Future<void>.delayed(Duration.zero);
    expect(starts, 2);
  });

  test('a repeated trigger inside the window does not start twice', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final links = StreamController<Uri>();
    addTearDown(links.close);
    var starts = 0;
    final notifier = container.read(quickRecordActionProvider.notifier);

    await notifier.bind(
      channel: channel,
      linkStream: links.stream,
      initialLink: Future<Uri?>.value(),
      startRecording: () async {
        starts++;
      },
    );

    links.add(Uri.parse('archiveme://action/record'));
    links.add(Uri.parse('archiveme://action/record'));
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
  });
}
