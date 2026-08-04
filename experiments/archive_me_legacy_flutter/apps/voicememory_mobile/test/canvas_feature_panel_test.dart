import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/shared/ui/animations/canvas_feature_panel.dart';

void main() {
  testWidgets('feature panel preserves the graph as its visible backdrop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(
                  key: Key('persistent_memory_graph'),
                  color: Colors.indigo,
                ),
              ),
              Builder(
                builder: (context) => IconButton(
                  key: const Key('open_canvas_panel'),
                  onPressed: () => showCanvasFeaturePanel<void>(
                    context: context,
                    builder: (_) =>
                        const Center(child: Text('Account panel content')),
                  ),
                  icon: const Icon(Icons.person),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_canvas_panel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('persistent_memory_graph')), findsOneWidget);
    expect(find.byKey(const Key('canvas_feature_panel')), findsOneWidget);
    expect(find.text('Account panel content'), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);
  });
}
