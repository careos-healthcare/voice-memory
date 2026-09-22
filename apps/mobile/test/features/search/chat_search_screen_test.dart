import 'package:archiveme_mobile/features/search/ui/chat_search_screen.dart';
import 'package:archiveme_mobile/features/search/vector_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('submitted question streams a reply and opens a citation', (
    tester,
  ) async {
    final service = VectorSearchService(
      store: MemoryTranscriptChunkStore(),
      embedder: (text) async => hashTranscriptEmbedding(text),
    );
    await service.indexTranscript(
      entryId: 'solar',
      transcript: 'The solar panel installation finally finished on the roof.',
    );
    String? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          semanticSearchServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: ChatSearchScreen(onOpenCitation: (id) => opened = id),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('chat_search_field')),
      'solar panel installation',
    );
    await tester.pump();
    expect(find.byKey(const Key('citation_chip_solar')), findsNothing);

    await tester.tap(find.byKey(const Key('chat_search_send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('solar panel installation'), findsWidgets);
    expect(find.byKey(const Key('citation_chip_solar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('citation_chip_solar')));
    expect(opened, 'solar');
  });
}
