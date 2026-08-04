import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/p2p_mesh/ui/mesh_ui_models.dart';
import 'package:voicememory_mobile/features/p2p_mesh/ui/vault_share_card.dart';
import 'package:voicememory_mobile/features/p2p_mesh/vault_share/vault_share_models.dart';

void main() {
  testWidgets('vault share card reports selection and injects callbacks', (
    tester,
  ) async {
    final selection = VaultShareSelection(
      clusterIds: const ['work', 'health'],
      includeCitationExcerpts: true,
      mediaAttachmentIds: const ['photo'],
    );
    VaultShareSelection? received;
    final haptics = <MeshHapticEvent>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VaultShareCard(
              selection: selection,
              clusterLabels: const {
                'work': 'Creative work',
                'health': 'Wellbeing',
              },
              onCreateShare: (value) => received = value,
              onHaptic: haptics.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('2 clusters'), findsOneWidget);
    expect(find.text('Citation excerpts'), findsOneWidget);
    expect(find.text('Creative work'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vault-share-create')));
    await tester.pump();
    expect(received, same(selection));
    expect(haptics, [MeshHapticEvent.selection, MeshHapticEvent.confirmation]);
  });

  testWidgets('vault share card surfaces action failures accessibly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultShareCard(
            selection: VaultShareSelection(clusterIds: const ['one']),
            onCreateShare: (_) => throw StateError('offline'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('vault-share-create')));
    await tester.pump();
    expect(find.byKey(const Key('vault-share-error')), findsOneWidget);
    expect(find.text('Could not create the share. Try again.'), findsOneWidget);
  });

  testWidgets('branch attribution is explicitly trusted and read only', (
    tester,
  ) async {
    final branch = SharedVaultBranch(
      shareId: 'share-1',
      createdAt: DateTime.utc(2026, 7, 1),
      importedAt: DateTime.utc(2026, 7, 27),
      attribution: const VaultShareSignerAttribution(
        signerId: 'Alex’s Vault',
        publicKeyFingerprint: '1234567890abcdef1234567890abcdef',
        status: VaultShareSignerStatus.trusted,
      ),
      clusters: const [],
      graph: PersonalKnowledgeGraph(),
    );
    SharedVaultBranch? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharedVaultBranchAttributionCard(
            branch: branch,
            onOpen: (value) => opened = value,
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Shared vault from Alex’s Vault, trusted signer, read only',
      ),
      findsOneWidget,
    );
    expect(find.text('Signer key 12345678…90abcdef'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shared-vault-branch-share-1')));
    expect(opened, same(branch));
  });
}
