import 'package:archiveme_mobile/features/pins/pinned_evidence_store.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Pin / unpin toggle for one entry. Writes safe metadata only and
/// shows a short receipt; the entry text and memory state are never
/// touched. Analytics carries counts and a stable source id — never
/// entry text or entry ids.
class PinEntryButton extends StatefulWidget {
  const PinEntryButton({
    required this.entryId, required this.isPinned, required this.store, super.key,
    this.source = 'entry_detail',
    this.onChanged,
  });

  final String entryId;
  final bool isPinned;
  final PinnedEvidenceStore store;

  /// Stable analytics source id only.
  final String source;

  final ValueChanged<bool>? onChanged;

  @override
  State<PinEntryButton> createState() => _PinEntryButtonState();
}

class _PinEntryButtonState extends State<PinEntryButton> {
  late bool _pinned = widget.isPinned;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.store.setPinned(widget.entryId, !_pinned);
      if (updated == null) return;
      if (!mounted) return;
      setState(() => _pinned = updated.isPinned);
      ActivationFunnelAnalytics.track(
        _pinned
            ? ActivationFunnelAnalytics.entryPinned
            : ActivationFunnelAnalytics.entryUnpinned,
        source: widget.source,
      );
      widget.onChanged?.call(_pinned);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _pinned
                ? PinnedEvidenceCopy.pinnedReceipt
                : PinnedEvidenceCopy.unpinnedReceipt,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _pinned
          ? PinnedEvidenceCopy.unpinAccessibilityLabel
          : PinnedEvidenceCopy.pinAccessibilityLabel,
      child: OutlinedButton.icon(
        key: const Key('pin_entry_button'),
        onPressed: _busy ? null : _toggle,
        icon: Icon(
          _pinned ? Icons.push_pin : Icons.push_pin_outlined,
          size: 18,
          color: _pinned ? AppColors.accentPrimary : AppColors.textSecondary,
        ),
        label: Text(
          _pinned
              ? PinnedEvidenceCopy.pinnedLabel
              : PinnedEvidenceCopy.pinLabel,
        ),
      ),
    );
  }
}