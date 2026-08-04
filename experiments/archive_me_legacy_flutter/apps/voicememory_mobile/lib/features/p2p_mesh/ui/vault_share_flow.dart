import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/graph/personal_knowledge_graph.dart';
import '../../../services/app_services.dart';
import '../../../storage/app_storage_paths.dart';
import '../../semantic_clusters/semantic_cluster.dart';
import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../vault_share/mesh_identity_vault_share_signer.dart';
import '../vault_share/vault_share_models.dart';
import 'vault_share_card.dart';

class VaultShareFlow {
  const VaultShareFlow._();

  static Future<void> showCluster(
    BuildContext context, {
    required SemanticCluster cluster,
    required PersonalKnowledgeGraph graph,
  }) async {
    final services = AppServices.instance;
    final shareService = services.vaultShareService;
    final identity = services.meshIdentityService;
    final vault = services.biometricVault;
    if (shareService == null || identity == null || vault == null) return;
    final selection = VaultShareSelection(
      clusterIds: [cluster.id],
      includeCitationExcerpts: true,
    );
    await showCanvasFeaturePanel<void>(
      context: context,
      routeName: 'vault-share',
      builder: (panelContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: VaultShareCard(
            selection: selection,
            title: 'Share ${cluster.title}',
            clusterLabels: {cluster.id: cluster.title},
            onCreateShare: (_) async {
              final password = await _password(
                panelContext,
                title: 'Protect this share',
                action: 'Create encrypted share',
              );
              if (password == null) return;
              final temporary = await AppStoragePaths.temporaryDirectory();
              final output = File(
                '${temporary.path}/archiveme-${DateTime.now().microsecondsSinceEpoch}.vshare',
              );
              try {
                final signer = await MeshIdentityVaultShareSigner.create(
                  identity,
                );
                await shareService.export(
                  output: output,
                  password: VaultSharePassword(password),
                  selection: selection,
                  clusters: [cluster],
                  graph: graph,
                  signer: signer,
                  biometricAuthorizer: BiometricVaultShareAuthorizer(vault),
                );
                final result = await Share.shareXFiles([
                  XFile(output.path, mimeType: 'application/octet-stream'),
                ], subject: 'ArchiveMe encrypted vault share');
                if (result.status != ShareResultStatus.success) {
                  throw StateError('The encrypted share was not sent.');
                }
              } finally {
                if (await output.exists()) await output.delete();
              }
            },
          ),
        ),
      ),
    );
  }

  static Future<void> importShare(BuildContext context) async {
    final services = AppServices.instance;
    final shareService = services.vaultShareService;
    final branchStore = services.sharedVaultBranchStore;
    final trustStore = services.meshTrustStore;
    if (shareService == null || branchStore == null || trustStore == null) {
      return;
    }
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['vshare'],
      allowMultiple: false,
    );
    final path = selected?.files.single.path;
    if (path == null || !context.mounted) return;
    final password = await _password(
      context,
      title: 'Open encrypted share',
      action: 'Import read-only branch',
    );
    if (password == null) return;
    final trust = MeshVaultShareTrust(await trustStore.list());
    await shareService.import(
      input: File(path),
      password: VaultSharePassword(password),
      signerTrust: trust,
      branchStore: branchStore,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Encrypted share imported as a read-only branch.'),
        ),
      );
    }
  }

  static Future<String?> _password(
    BuildContext context, {
    required String title,
    required String action,
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            key: const Key('vault-share-password'),
            controller: controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Password',
              helperText: 'Use at least 12 characters.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.length < 12) return;
                Navigator.pop(dialogContext, controller.text);
              },
              child: Text(action),
            ),
          ],
        ),
      );
    } finally {
      controller.clear();
      controller.dispose();
    }
  }
}
