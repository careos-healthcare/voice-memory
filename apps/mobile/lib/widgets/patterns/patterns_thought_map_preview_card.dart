import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_belief_correction_store.dart';
import 'package:archiveme_mobile/features/archive_thought_map/archive_thought_map_copy.dart';
import 'package:archiveme_mobile/features/archive_thought_map/archive_thought_map_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Lightweight thought map preview on the Patterns tab — local evidence only.
class PatternsThoughtMapPreviewCard extends StatefulWidget {
  const PatternsThoughtMapPreviewCard({required this.preview, super.key});

  final ArchiveThoughtMapPreview preview;

  @override
  State<PatternsThoughtMapPreviewCard> createState() =>
      _PatternsThoughtMapPreviewCardState();
}

class _PatternsThoughtMapPreviewCardState
    extends State<PatternsThoughtMapPreviewCard> {
  late String _threadTitle;
  bool _renaming = false;
  bool _feelsRightConfirmed = false;
  bool _notQuiteShown = false;
  bool _renameConfirmed = false;
  String? _selectedNodeId;
  final _renameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _threadTitle = widget.preview.threadTitle;
    _renameController.text = _threadTitle;
  }

  @override
  void didUpdateWidget(covariant PatternsThoughtMapPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview.suggestionId != widget.preview.suggestionId) {
      _selectedNodeId = null;
    }
    if (oldWidget.preview.suggestionId != widget.preview.suggestionId ||
        (oldWidget.preview.threadTitle != widget.preview.threadTitle &&
            !_renaming)) {
      _threadTitle = widget.preview.threadTitle;
      _renameController.text = _threadTitle;
    }
  }

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  ArchiveThoughtMapNode? get _selectedNode {
    final id = _selectedNodeId;
    if (id == null) return null;
    for (final node in widget.preview.nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  void _onFeelsRight() {
    ArchiveBeliefCorrectionStore.markSaved(widget.preview.suggestionId);
    setState(() {
      _feelsRightConfirmed = true;
      _notQuiteShown = false;
      _renameConfirmed = false;
      _renaming = false;
    });
  }

  void _onNotQuite() {
    ArchiveBeliefCorrectionStore.dismiss(widget.preview.suggestionId);
    setState(() {
      _notQuiteShown = true;
      _feelsRightConfirmed = false;
      _renameConfirmed = false;
      _renaming = false;
    });
  }

  void _startRename() {
    _renameController.text = _threadTitle;
    setState(() {
      _renaming = true;
      _renameConfirmed = false;
    });
  }

  void _saveRename() {
    final normalized = ArchiveBeliefCorrectionStore.sanitizeRenamedTitle(
      _renameController.text,
    );
    if (normalized == null) return;
    ArchiveBeliefCorrectionStore.renameThread(
      widget.preview.suggestionId,
      normalized,
    );
    setState(() {
      _threadTitle = normalized;
      _renaming = false;
      _renameConfirmed = true;
    });
  }

  void _selectNode(String nodeId) {
    setState(() => _selectedNodeId = nodeId);
  }

  void _closeEvidencePanel() {
    setState(() => _selectedNodeId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.preview.shouldShow) {
      return const SizedBox.shrink(
        key: Key('patterns_thought_map_preview_hidden'),
      );
    }

    final preview = widget.preview;
    final selectedNode = _selectedNode;

    return Container(
      key: const Key('patterns_thought_map_preview_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9F4),
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: VoiceMemoryCards.standard().boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveThoughtMapCopy.sectionTitle,
            key: const Key('patterns_thought_map_preview_section_title'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          if (preview.stageLabel case final stage?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${ArchiveThoughtMapCopy.stageLabelPrefix} $stage',
              key: const Key('patterns_thought_map_stage_label'),
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          if (_renaming) ...[
            TextField(
              key: const Key('patterns_thought_map_rename_field'),
              controller: _renameController,
              decoration: const InputDecoration(
                hintText: ArchiveThoughtMapCopy.renameFieldHint,
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveRename(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                key: const Key('patterns_thought_map_rename_save'),
                onPressed: _saveRename,
                child: const Text(ArchiveThoughtMapCopy.renameSaveCta),
              ),
            ),
          ] else ...[
            Text(
              _threadTitle,
              key: const Key('patterns_thought_map_thread_title'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            if (_renameConfirmed) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                ArchiveThoughtMapCopy.threadRenamedConfirmation,
                key: const Key('patterns_thought_map_rename_confirmation'),
                style: ArchiveMobileTypography.responsiveHelper(context),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          ..._nodeRows(context, preview),
          if (selectedNode != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _EvidencePanel(
              node: selectedNode,
              onClose: _closeEvidencePanel,
              onRecordAnother: () => context.go('/record'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            ArchiveThoughtMapCopy.evidenceLine(preview.savedMomentCount),
            key: const Key('patterns_thought_map_evidence_line'),
            style: ArchiveMobileTypography.responsiveHelper(context),
          ),
          if (preview.changeLine case final change?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              change,
              key: const Key('patterns_thought_map_change_line'),
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_feelsRightConfirmed)
            Text(
              ArchiveThoughtMapCopy.feelsRightConfirmation,
              key: const Key('patterns_thought_map_feels_right_confirmation'),
              style: ArchiveMobileTypography.responsiveHelper(context),
            )
          else if (_notQuiteShown)
            Text(
              ArchiveThoughtMapCopy.notQuiteMessage,
              key: const Key('patterns_thought_map_not_quite_message'),
              style: ArchiveMobileTypography.responsiveHelper(context),
            )
          else ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  key: const Key('patterns_thought_map_feels_right'),
                  onPressed: _onFeelsRight,
                  child: const Text(ArchiveThoughtMapCopy.feelsRightCta),
                ),
                OutlinedButton(
                  key: const Key('patterns_thought_map_rename_thread'),
                  onPressed: _startRename,
                  child: const Text(ArchiveThoughtMapCopy.renameThreadCta),
                ),
                OutlinedButton(
                  key: const Key('patterns_thought_map_not_quite'),
                  onPressed: _onNotQuite,
                  child: const Text(ArchiveThoughtMapCopy.notQuiteCta),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _nodeRows(
    BuildContext context,
    ArchiveThoughtMapPreview preview,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < preview.nodes.length; i++) {
      final node = preview.nodes[i];
      if (i > 0 && i - 1 < preview.connectors.length) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              ArchiveThoughtMapCopy.connectorLabel(preview.connectors[i - 1]),
              key: Key('patterns_thought_map_connector_$i'),
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }
      final selected = _selectedNodeId == node.id;
      rows.add(
        Material(
          color: selected
              ? AppColors.accentPrimary.withValues(alpha: 0.08)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: Key('patterns_thought_map_node_tap_${node.kind.name}'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => _selectNode(node.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
                horizontal: AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      node.label,
                      key: Key(
                        'patterns_thought_map_node_label_${node.kind.name}',
                      ),
                      style: ArchiveMobileTypography.cardLabel(context),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      node.value,
                      key: Key(
                        'patterns_thought_map_node_value_${node.kind.name}',
                      ),
                      style: ArchiveMobileTypography.body(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return rows;
  }
}

class _EvidencePanel extends StatelessWidget {
  const _EvidencePanel({
    required this.node,
    required this.onClose,
    required this.onRecordAnother,
  });

  final ArchiveThoughtMapNode node;
  final VoidCallback onClose;
  final VoidCallback onRecordAnother;

  @override
  Widget build(BuildContext context) {
    final count = node.supportingMomentCount > 0
        ? node.supportingMomentCount
        : node.snippets.length;

    return Container(
      key: const Key('patterns_thought_map_evidence_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveThoughtMapCopy.whyNodeAppearsTitle,
            key: const Key('patterns_thought_map_why_node_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            node.label,
            key: Key(
              'patterns_thought_map_evidence_node_label_${node.kind.name}',
            ),
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ArchiveThoughtMapCopy.evidenceLine(count),
            key: const Key('patterns_thought_map_node_evidence_line'),
            style: ArchiveMobileTypography.responsiveHelper(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (node.snippets.isEmpty)
            Text(
              ArchiveThoughtMapCopy.nodeEvidenceFallback,
              key: const Key('patterns_thought_map_node_evidence_fallback'),
              style: ArchiveMobileTypography.body(context),
            )
          else
            ...node.snippets.map(
              (snippet) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snippet.excerpt,
                      key: Key(
                        'patterns_thought_map_snippet_${node.kind.name}_${snippet.entryId}',
                      ),
                      style: ArchiveMobileTypography.body(context),
                    ),
                    Text(
                      ArchiveThoughtMapCopy.savedAtLabel(snippet.savedAt),
                      style: ArchiveMobileTypography.responsiveHelper(
                        context,
                      ).copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveThoughtMapCopy.patternSignalDisclaimer,
            key: const Key('patterns_thought_map_pattern_signal_disclaimer'),
            style: ArchiveMobileTypography.responsiveHelper(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(
                key: const Key('patterns_thought_map_record_another_moment'),
                onPressed: onRecordAnother,
                child: const Text(ArchiveThoughtMapCopy.recordAnotherMomentCta),
              ),
              OutlinedButton(
                key: const Key('patterns_thought_map_evidence_close'),
                onPressed: onClose,
                child: const Text(ArchiveThoughtMapCopy.closeCta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}