import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../vault_share/vault_share_models.dart';
import 'mesh_ui_models.dart';

typedef VaultShareAction =
    FutureOr<void> Function(VaultShareSelection selection);

class VaultShareCard extends StatefulWidget {
  const VaultShareCard({
    super.key,
    required this.selection,
    this.title = 'Vault share',
    this.clusterLabels = const {},
    this.onCreateShare,
    this.onBeam,
    this.onHaptic,
  });

  final VaultShareSelection selection;
  final String title;
  final Map<String, String> clusterLabels;
  final VaultShareAction? onCreateShare;
  final VaultShareAction? onBeam;
  final MeshHapticCallback? onHaptic;

  @override
  State<VaultShareCard> createState() => _VaultShareCardState();
}

class _VaultShareCardState extends State<VaultShareCard> {
  var _busy = false;
  String? _error;

  Future<void> _run(VaultShareAction action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.onHaptic?.call(MeshHapticEvent.selection);
      await action(widget.selection);
      if (mounted) widget.onHaptic?.call(MeshHapticEvent.confirmation);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Could not create the share. Try again.');
        widget.onHaptic?.call(MeshHapticEvent.warning);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = widget.selection;
    final clusterCount = selection.clusterIds.length;
    return Semantics(
      container: true,
      label:
          '${widget.title}, $clusterCount selected '
          '${clusterCount == 1 ? 'cluster' : 'clusters'}, encrypted share',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Card(
            key: const Key('vault-share-card'),
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: .58,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: .28),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: theme.colorScheme.primary,
                        semanticLabel: 'Encrypted',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Creates a signed, encrypted copy. Your original vault stays private.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailChip(
                        icon: Icons.bubble_chart_outlined,
                        label:
                            '$clusterCount ${clusterCount == 1 ? 'cluster' : 'clusters'}',
                      ),
                      if (selection.includeCitationExcerpts)
                        const _DetailChip(
                          icon: Icons.format_quote,
                          label: 'Citation excerpts',
                        ),
                      if (selection.mediaAttachmentIds.isNotEmpty)
                        _DetailChip(
                          icon: Icons.perm_media_outlined,
                          label: '${selection.mediaAttachmentIds.length} media',
                        ),
                    ],
                  ),
                  if (widget.clusterLabels.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 112),
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          key: const Key('vault-share-cluster-scroll'),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final id in selection.clusterIds)
                                Chip(
                                  label: Text(widget.clusterLabels[id] ?? id),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        key: const Key('vault-share-error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const Key('vault-share-create'),
                        onPressed: widget.onCreateShare == null || _busy
                            ? null
                            : () => _run(widget.onCreateShare!),
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.ios_share),
                        label: const Text('Create share'),
                      ),
                      if (widget.onBeam != null)
                        FilledButton.tonalIcon(
                          key: const Key('vault-share-beam'),
                          onPressed: _busy ? null : () => _run(widget.onBeam!),
                          icon: const Icon(Icons.near_me_outlined),
                          label: const Text('Beam nearby'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SharedVaultBranchAttributionCard extends StatelessWidget {
  const SharedVaultBranchAttributionCard({
    super.key,
    required this.branch,
    this.onOpen,
  });

  final SharedVaultBranch branch;
  final ValueChanged<SharedVaultBranch>? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trusted = branch.attribution.isTrusted;
    final clusterCount = branch.clusters.length;
    final label =
        'Shared vault from ${branch.attribution.signerId}, '
        '${trusted ? 'trusted signer' : 'unknown signer'}, read only';
    return Semantics(
      container: true,
      button: onOpen != null,
      readOnly: true,
      label: label,
      child: Card(
        key: Key('shared-vault-branch-${branch.shareId}'),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color:
                (trusted ? theme.colorScheme.tertiary : theme.colorScheme.error)
                    .withValues(alpha: .42),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen == null ? null : () => onOpen!(branch),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  trusted
                      ? Icons.verified_user_outlined
                      : Icons.gpp_maybe_outlined,
                  color: trusted
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.error,
                  semanticLabel: trusted ? 'Trusted signer' : 'Unknown signer',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shared by ${branch.attribution.signerId}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$clusterCount ${clusterCount == 1 ? 'cluster' : 'clusters'} · Read only',
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Signer key ${_shortFingerprint(branch.attribution.publicKeyFingerprint)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Imported ${_dateLabel(branch.importedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (onOpen != null)
                  const Icon(
                    Icons.chevron_right,
                    semanticLabel: 'Open read-only branch',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(label)],
    ),
  );
}

String _shortFingerprint(String fingerprint) {
  if (fingerprint.length <= 16) return fingerprint;
  return '${fingerprint.substring(0, 8)}…${fingerprint.substring(fingerprint.length - 8)}';
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
