import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/user_facing_date.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';

/// Observation with inline depth — expand, evidence, rationale, related entries.
class ExpandableObservationField extends StatefulWidget {
  const ExpandableObservationField({
    super.key,
    required this.label,
    required this.value,
    this.rationale,
    this.entryId,
    this.relatedEntries = const [],
  });

  final String label;
  final String value;
  final String? rationale;
  final String? entryId;
  final List<JournalEntry> relatedEntries;

  @override
  State<ExpandableObservationField> createState() =>
      _ExpandableObservationFieldState();
}

class _ExpandableObservationFieldState extends State<ExpandableObservationField> {
  var _tellMoreExpanded = false;
  var _whyExpanded = false;
  var _relatedExpanded = false;

  static const _shortLimit = 140;

  bool get _isLong => widget.value.length > _shortLimit;

  String get _displayText {
    if (_tellMoreExpanded || !_isLong) return widget.value;
    return '${widget.value.substring(0, _shortLimit).trim()}…';
  }

  @override
  Widget build(BuildContext context) {
    final related = widget.relatedEntries;
    final hasRelated = related.isNotEmpty;

    return Semantics(
      label: '${widget.label} archive insight',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 0.6,
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _displayText,
              style: const TextStyle(
                color: AppTheme.foreground,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_isLong)
                  _actionChip(
                    label: _tellMoreExpanded ? 'Show less' : 'Tell me more',
                    onPressed: () =>
                        setState(() => _tellMoreExpanded = !_tellMoreExpanded),
                  ),
                if (widget.entryId != null)
                  _actionChip(
                    label: 'Show evidence',
                    onPressed: () => context.push('/entry/${widget.entryId}'),
                  ),
                _actionChip(
                  label: 'Why does the archive think this?',
                  onPressed: () => setState(() => _whyExpanded = !_whyExpanded),
                ),
                if (hasRelated)
                  _actionChip(
                    label: 'Related entries',
                    onPressed: () =>
                        setState(() => _relatedExpanded = !_relatedExpanded),
                  ),
              ],
            ),
            if (_whyExpanded) ...[
              const SizedBox(height: 12),
              Text(
                widget.rationale?.trim().isNotEmpty == true
                    ? widget.rationale!.trim()
                    : 'This comes from patterns in your transcripts — '
                        'recurring themes and repeated language, not a guess.',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
            if (_relatedExpanded && hasRelated) ...[
              const SizedBox(height: 12),
              ...related.take(5).map(_relatedEntryTile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionChip({required String label, required VoidCallback onPressed}) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.foreground),
            ),
          ),
        ),
      ),
    );
  }

  Widget _relatedEntryTile(JournalEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => context.push('/entry/${entry.id}'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatUserFacingDate(entry.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.transcript.length > 80
                            ? '${entry.transcript.substring(0, 80)}…'
                            : entry.transcript,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: AppTheme.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
