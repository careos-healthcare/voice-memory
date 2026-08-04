import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/widgets/emergency_vault_recovery_banner.dart';

void main() {
  group('EmergencyVaultRecoveryBanner', () {
    testWidgets('shows duration, chunk count, and action buttons', (
      tester,
    ) async {
      var recovered = false;
      var discarded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyVaultRecoveryBanner(
              recoveredChunkCount: 12,
              totalDuration: const Duration(seconds: 83),
              onRecover: () => recovered = true,
              onDiscard: () => discarded = true,
            ),
          ),
        ),
      );

      expect(find.text('Unsaved audio recovered'), findsOneWidget);
      expect(find.textContaining('01:23'), findsOneWidget);
      expect(find.textContaining('12 chunks'), findsOneWidget);

      await tester.tap(find.text('Restore'));
      await tester.pump();
      expect(recovered, isTrue);

      await tester.tap(find.text('Discard'));
      await tester.pump();
      expect(discarded, isTrue);
    });

    testWidgets('uses singular chunk label for one frame', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyVaultRecoveryBanner(
              recoveredChunkCount: 1,
              totalDuration: const Duration(seconds: 4),
              onRecover: () {},
              onDiscard: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('1 chunk)'), findsOneWidget);
    });
  });
}
