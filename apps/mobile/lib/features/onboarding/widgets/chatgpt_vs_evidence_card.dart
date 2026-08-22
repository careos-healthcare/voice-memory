import 'package:archiveme_mobile/features/onboarding/chatgpt_vs_evidence_builder.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_copy.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_telemetry.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_copy.dart';
import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Side-by-side "ChatGPT vs Evidence Method" proof for first-session onboarding.
class ChatGptVsEvidenceCard extends StatefulWidget {
  const ChatGptVsEvidenceCard({
    required this.payload, super.key,
    this.onVerified,
  });

  final ChatGptVsEvidencePayload payload;
  final VoidCallback? onVerified;

  @override
  State<ChatGptVsEvidenceCard> createState() => _ChatGptVsEvidenceCardState();
}

class _ChatGptVsEvidenceCardState extends State<ChatGptVsEvidenceCard> {
  bool _showChatComparison = true;
  var _toggleLogged = false;

  ChatGptVsEvidencePayload get payload => widget.payload;

  Future<void> _onToggleChanged(bool value) async {
    setState(() => _showChatComparison = value);
    if (!_toggleLogged) {
      _toggleLogged = true;
      await ExperimentHTelemetry.trackToggleInteracted(
        showingChatComparison: value,
      );
    }
  }

  Future<void> _verifyInsight() async {
    await ExperimentHTelemetry.trackFirstInsightVerified(
      entryId: payload.entry.id,
    );
    widget.onVerified?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('experiment_h_compare_toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text(ExperimentHCopy.toggleLabel),
          subtitle: const Text(ExperimentHCopy.toggleHint),
          value: _showChatComparison,
          onChanged: _onToggleChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_showChatComparison)
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _ChatPanel(payload: payload)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _EvidencePanel(payload: payload)),
                  ],
                )
              : Column(
                  children: [
                    _ChatPanel(payload: payload),
                    const SizedBox(height: AppSpacing.md),
                    _EvidencePanel(payload: payload),
                  ],
                )
        else
          _EvidencePanel(payload: payload),
        const SizedBox(height: AppSpacing.md),
        _ArchitectureCompareRow(showChatComparison: _showChatComparison),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          key: const Key('experiment_h_verify_button'),
          onPressed: _verifyInsight,
          child: const Text(ExperimentHCopy.verifyCta),
        ),
      ],
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({required this.payload});

  final ChatGptVsEvidencePayload payload;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      key: const Key('experiment_h_chat_panel'),
      title: ExperimentHCopy.chatPanelTitle,
      subtitle: ExperimentHCopy.chatPanelSubtitle,
      accent: AppColors.textSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            payload.ephemeralSummary,
            style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ExperimentHCopy.assumptionGenerative,
            style: VoiceMemoryTypography.secondaryStyle().copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidencePanel extends StatelessWidget {
  const _EvidencePanel({required this.payload});

  final ChatGptVsEvidencePayload payload;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      key: const Key('experiment_h_evidence_panel'),
      title: ExperimentHCopy.evidencePanelTitle,
      subtitle: ExperimentHCopy.evidencePanelSubtitle,
      accent: VoiceMemoryColors.primaryIndigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfidenceBadge(band: payload.confidenceBand),
          const SizedBox(height: AppSpacing.sm),
          Text(
            payload.evidenceSummary,
            style: VoiceMemoryTypography.bodyStyle().copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (payload.isEmpty)
            Text(
              ExperimentHCopy.emptyEntryBody,
              style: VoiceMemoryTypography.secondaryStyle(),
            )
          else ...[
            if (payload.isShort)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  ExperimentHCopy.shortEntryBody,
                  style: VoiceMemoryTypography.secondaryStyle(),
                ),
              ),
            Text(
              payload.recordedAtLabel,
              style: VoiceMemoryTypography.secondaryStyle().copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              payload.quote.isEmpty ? '(No transcript saved yet)' : payload.quote,
              style: VoiceMemoryTypography.bodyStyle().copyWith(
                height: 1.45,
                color: VoiceMemoryColors.primaryIndigo,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              PatternMatchQualityCopy.explanationFor(payload.confidenceBand),
              style: VoiceMemoryTypography.secondaryStyle(),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final line in payload.factLedgerLines)
              Text(
                line,
                style: VoiceMemoryTypography.secondaryStyle().copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ArchitectureCompareRow extends StatelessWidget {
  const _ArchitectureCompareRow({required this.showChatComparison});

  final bool showChatComparison;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showChatComparison) ...[
            Text(
              ExperimentHCopy.architectureEphemeral,
              style: VoiceMemoryTypography.secondaryStyle(),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            ExperimentHCopy.architectureLedger,
            style: VoiceMemoryTypography.bodyStyle().copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ExperimentHCopy.assumptionCitable,
            style: VoiceMemoryTypography.secondaryStyle(),
          ),
        ],
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.title, required this.subtitle, required this.accent, required this.child, super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: VoiceMemoryCards.standard(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                fontSize: 16,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: VoiceMemoryTypography.secondaryStyle()),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.band});

  final PatternMatchConfidenceBand band;

  @override
  Widget build(BuildContext context) {
    final label = switch (band) {
      PatternMatchConfidenceBand.weak => 'Weak',
      PatternMatchConfidenceBand.emerging => 'Emerging',
      PatternMatchConfidenceBand.solid => 'Solid',
      PatternMatchConfidenceBand.strong => 'Strong',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: VoiceMemoryTypography.bodyStyle(
          color: VoiceMemoryColors.primaryIndigo,
        ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}