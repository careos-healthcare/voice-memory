import 'dart:convert';

import 'package:archiveme_mobile/features/recording/streaming_transcript_session.dart';
import 'package:archiveme_mobile/widgets/record/streaming_transcript_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assembles a chunked transcription frame without jumping backward', () {
    final session = StreamingTranscriptSession();
    const frame =
        '{"serverContent":{"inputTranscription":{"text":"hello there"}}}';
    final cut = frame.indexOf('there');
    session.addChunkBytes(utf8.encode(frame.substring(0, cut)));
    expect(session.current, isEmpty);
    session.addChunkBytes(utf8.encode('${frame.substring(cut)}\n'));
    expect(session.current, 'hello there');

    session.addWebSocketFrame(
      '{"serverContent":{"inputTranscription":{"text":"hello"}}}',
    );
    expect(session.current, 'hello there');

    session.addDelta('today');
    expect(session.current, 'hello there today');
  });

  test('provider keeps the latest stable line', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(streamingTranscriptProvider.notifier)
        .addWebSocketFrame(
          '{"serverContent":{"inputTranscription":{"text":"hello live voice"}}}',
        );
    expect(container.read(streamingTranscriptProvider), 'hello live voice');
  });

  testWidgets('eases a fast burst instead of jumping the transcript', (
    tester,
  ) async {
    const first = 'one two three four five six seven eight nine ten';
    await tester.pumpWidget(_host(first));
    await tester.pump();

    await tester.pumpWidget(
      _host('$first eleven twelve thirteen fourteen fifteen sixteen'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final position = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!
        .position;
    expect(position.pixels, greaterThan(0));
    expect(position.pixels, lessThan(position.maxScrollExtent - 1));
    expect(find.textContaining('sixteen'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
  });
}

Widget _host(String text) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 80,
          child: StreamingTranscriptText(text: text, height: 36),
        ),
      ),
    ),
  );
}
