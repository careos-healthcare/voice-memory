import 'dart:async';

import 'package:archiveme_mobile/features/llm/domain/llm_feed_card_state.dart';
import 'package:archiveme_mobile/features/llm/presentation/llm_stream_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StreamBuilder renders accumulating tokens', (tester) async {
    final controller = StreamController<LlmStreamToken>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LlmStreamPanel(tokenStream: controller.stream),
        ),
      ),
    );

    expect(find.byKey(const Key('llm_stream_panel')), findsOneWidget);
    expect(find.text('Analyzing reflection…'), findsOneWidget);

    controller.add(
      const LlmStreamToken(
        captureId: 'c1',
        token: '{"entryId"',
        accumulatedText: '{"entryId"',
      ),
    );
    await tester.pump();

    expect(find.textContaining('"entryId"'), findsOneWidget);

    await controller.close();
  });
}
