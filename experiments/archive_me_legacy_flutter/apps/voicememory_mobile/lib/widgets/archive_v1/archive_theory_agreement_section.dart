import 'package:flutter/material.dart';

import '../../design/user_facing_date.dart';
import '../../features/archive_agreement/archive_agreement_copy.dart';
import '../../features/archive_agreement/archive_agreement_models.dart';
import '../../features/archive_agreement/archive_agreement_service.dart';
import '../../features/archive_theory/archive_theory_models.dart';
import '../../services/app_services.dart';
import '../../theme/app_theme.dart';
import '../../theme/voicememory_colors.dart';
import '../../theme/voicememory_typography.dart';

/// Agree / Unsure / Disagree on the current theory — metadata only.
class ArchiveTheoryAgreementSection extends StatefulWidget {
  const ArchiveTheoryAgreementSection({super.key, required this.theory});

  final ArchiveCurrentTheory theory;

  @override
  State<ArchiveTheoryAgreementSection> createState() =>
      _ArchiveTheoryAgreementSectionState();
}

class _ArchiveTheoryAgreementSectionState
    extends State<ArchiveTheoryAgreementSection> {
  ArchiveAgreementHistoryView? _history;
  ArchiveTheoryAgreementResponse? _selected;
  bool _loading = true;
  bool _saving = false;

  ArchiveAgreementService get _service => AppServices.instance.archiveAgreement;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ArchiveTheoryAgreementSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theory.statement != widget.theory.statement) {
      _load();
    }
  }

  Future<void> _load() async {
    final view = await _service.historyForTheory(
      currentTheoryStatement: widget.theory.statement,
    );
    if (!mounted) return;
    setState(() {
      _history = view;
      _selected = view.latestForCurrentTheory?.response;
      _loading = false;
    });
  }

  Future<void> _onResponse(ArchiveTheoryAgreementResponse response) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.record(
        theoryStatement: widget.theory.statement,
        response: response,
        confidencePercent: widget.theory.confidencePercent,
      );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _panel(
        child: const SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveAgreementCopy.sectionTitle,
            style: VoiceMemoryTypography.sectionTitleStyle(),
          ),
          const SizedBox(height: 8),
          Text(
            ArchiveAgreementCopy.prompt,
            style: const TextStyle(
              color: AppTheme.foreground,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _responseRow(),
          const SizedBox(height: 10),
          Text(
            ArchiveAgreementCopy.metadataNote,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            ArchiveAgreementCopy.historyTitle,
            style: VoiceMemoryTypography.sectionLabelStyle(),
          ),
          const SizedBox(height: 8),
          ..._historyTiles(),
        ],
      ),
    );
  }

  Widget _responseRow() {
    return Row(
      children: [
        Expanded(
          child: _responseButton(
            ArchiveTheoryAgreementResponse.agree,
            ArchiveAgreementCopy.agreeLabel,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _responseButton(
            ArchiveTheoryAgreementResponse.unsure,
            ArchiveAgreementCopy.unsureLabel,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _responseButton(
            ArchiveTheoryAgreementResponse.disagree,
            ArchiveAgreementCopy.disagreeLabel,
          ),
        ),
      ],
    );
  }

  Widget _responseButton(
    ArchiveTheoryAgreementResponse response,
    String label,
  ) {
    final selected = _selected == response;
    return FilledButton.tonal(
      onPressed: _saving ? null : () => _onResponse(response),
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.18)
            : VoiceMemoryColors.surfaceSecondary,
        foregroundColor: selected
            ? VoiceMemoryColors.primaryIndigo
            : AppTheme.foreground,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected
                ? VoiceMemoryColors.primaryIndigo
                : VoiceMemoryColors.border,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  List<Widget> _historyTiles() {
    final records = _history?.records ?? const [];
    if (records.isEmpty) {
      return [
        Text(
          ArchiveAgreementCopy.historyEmpty,
          style: const TextStyle(color: AppTheme.muted, height: 1.45),
        ),
      ];
    }

    return records.map(_historyTile).toList();
  }

  Widget _historyTile(ArchiveAgreementRecord record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ArchiveAgreementCopy.responseLabel(record.response),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ArchiveAgreementCopy.truncateTheory(record.theoryStatement),
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatUserFacingDate(record.recordedAt),
            style: const TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: child,
    );
  }
}
