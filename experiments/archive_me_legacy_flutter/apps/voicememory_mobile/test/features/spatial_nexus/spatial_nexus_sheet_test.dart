import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/spatial_nexus/spatial_nexus_models.dart';
import 'package:voicememory_mobile/features/spatial_nexus/ui/spatial_nexus_sheet.dart';

void main() {
  testWidgets(
    'switches environment and triggers fullscreen immersive fallback',
    (tester) async {
      var preset = SpatialEnvironmentPreset.neuralVoid;
      var immersiveCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SpatialNexusSheet(
                initialPreset: preset,
                capabilities: const [
                  SpatialCapability.unavailable(
                    SpatialNativeCapability.metal,
                    'Metal renderer binary is not packaged.',
                  ),
                ],
                onPresetChanged: (value) => preset = value,
                onEnterImmersive: () => immersiveCount++,
                onExportSnapshot: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('spatial-nexus-sheet')), findsOneWidget);
      expect(find.textContaining('Metal renderer binary'), findsOneWidget);

      await tester.tap(find.text('Cyber Grid'));
      await tester.pump();
      expect(preset, SpatialEnvironmentPreset.cyberneticGrid);

      await tester.scrollUntilVisible(
        find.byKey(const Key('spatial-nexus-immersive')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('spatial-nexus-immersive')));
      await tester.pump();
      expect(immersiveCount, 1);
    },
  );
}
