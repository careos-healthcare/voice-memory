import 'package:archiveme_mobile/features/proof_admission/verified_proof_view_model.dart';
import 'package:flutter/material.dart';

/// The one proof-detail surface: a single scrollable sheet over a single source.
///
/// Every dimension comes from [VerifiedProofViewModel] and is rendered only when
/// that view model populated it, so an absent dimension leaves no heading and no
/// placeholder behind. Nothing here can render a percentage, a numeric score, or
/// a ranking position, because the sheet only prints the plain-language lines the
/// view model already produced.
class ProofDetailSheet extends StatelessWidget {
  const ProofDetailSheet({
    required this.proof, super.key,
    this.onOpenEvidence,
    this.correctionControls,
  });

  static const String supportingHeading = 'Evidence supporting this';
  static const String againstHeading = 'Evidence against this';
  static const String frequencyHeading = 'How often it appeared';
  static const String changeHeading = 'What changed over time';
  static const String occurrenceHeading = 'First and latest occurrence';
  static const String missingHeading = 'What is still missing';
  static const String correctionsHeading = 'Your corrections';

  static const String earlierMomentLabel = 'The earlier moment';
  static const String latestMomentLabel = 'The latest moment';
  static const String staleNote = 'This is based on older evidence.';

  static const double minTapTarget = 48;

  final VerifiedProofViewModel proof;

  /// The caller owns navigation, so the sheet never names a route itself.
  final ValueChanged<String>? onOpenEvidence;

  /// Correction affordances are injected rather than constructed here. That keeps
  /// the verified view model as this widget's only data dependency.
  final Widget? correctionControls;

  static Future<void> show(
    BuildContext context, {
    required VerifiedProofViewModel proof,
    ValueChanged<String>? onOpenEvidence,
    Widget? correctionControls,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ProofDetailSheet(
      proof: proof,
      onOpenEvidence: onOpenEvidence,
      correctionControls: correctionControls,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      ..._statement(context),
      ..._supportingSection(context),
      ..._againstSection(context),
      ..._frequencySection(context),
      ..._changeSection(context),
      ..._occurrenceSection(context),
      ..._missingSection(context),
      ..._correctionsSection(context),
      ?correctionControls,
    ];

    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('proof_detail_scroll'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  List<Widget> _statement(BuildContext context) {
    final theme = Theme.of(context);
    return [
      Text(
        proof.statement,
        key: const Key('proof_detail_statement'),
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      Text(
        proof.confidenceLabel,
        key: const Key('proof_detail_confidence'),
        style: theme.textTheme.labelLarge,
      ),
      if (proof.stale)
        Text(
          staleNote,
          key: const Key('proof_detail_stale'),
          style: theme.textTheme.bodySmall,
        ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _supportingSection(BuildContext context) {
    if (proof.supportingEvidence.isEmpty) return const [];
    return _section(context, supportingHeading, [
      for (var index = 0; index < proof.supportingEvidence.length; index++)
        _evidenceRow(
          context,
          proof.supportingEvidence[index],
          keyName: 'proof_detail_supporting_$index',
        ),
    ]);
  }

  /// Counterexamples and contradictions share one section and are never dropped
  /// to make a proof look cleaner than its evidence.
  List<Widget> _againstSection(BuildContext context) {
    final against = [...proof.counterexamples, ...proof.contradictions];
    if (against.isEmpty) return const [];
    return _section(context, againstHeading, [
      for (var index = 0; index < against.length; index++)
        _evidenceRow(
          context,
          against[index],
          keyName: 'proof_detail_against_$index',
        ),
    ]);
  }

  List<Widget> _frequencySection(BuildContext context) {
    final line = proof.frequencyLine;
    if (line == null) return const [];
    return _section(context, frequencyHeading, [
      _line(context, line, keyName: 'proof_detail_frequency_line'),
    ]);
  }

  List<Widget> _changeSection(BuildContext context) {
    final trend = proof.trendLine;
    final strength = proof.strengthLine;
    final then = proof.thenEvidence;
    final now = proof.nowEvidence;
    final hasChange = proof.hasChangeEvidence;
    if (trend == null && strength == null && !hasChange) return const [];
    return _section(context, changeHeading, [
      if (trend != null) _line(context, trend, keyName: 'proof_detail_trend'),
      if (strength != null)
        _line(context, strength, keyName: 'proof_detail_strength'),
      if (hasChange && then != null)
        _labelledEvidence(
          context,
          earlierMomentLabel,
          then,
          keyName: 'proof_detail_then',
        ),
      if (hasChange && now != null)
        _labelledEvidence(
          context,
          latestMomentLabel,
          now,
          keyName: 'proof_detail_now',
        ),
    ]);
  }

  List<Widget> _occurrenceSection(BuildContext context) {
    if (!proof.hasOccurrenceRange) return const [];
    return _section(context, occurrenceHeading, [
      _line(
        context,
        'First seen ${formatEvidenceDate(proof.firstOccurrence!)}.',
        keyName: 'proof_detail_first_occurrence',
      ),
      _line(
        context,
        'Most recently seen ${formatEvidenceDate(proof.lastOccurrence!)}.',
        keyName: 'proof_detail_last_occurrence',
      ),
    ]);
  }

  List<Widget> _missingSection(BuildContext context) {
    if (proof.missingEvidenceLines.isEmpty) return const [];
    return _section(context, missingHeading, [
      for (var index = 0; index < proof.missingEvidenceLines.length; index++)
        _line(
          context,
          proof.missingEvidenceLines[index],
          keyName: 'proof_detail_missing_$index',
        ),
    ]);
  }

  List<Widget> _correctionsSection(BuildContext context) {
    if (proof.correctionLines.isEmpty) return const [];
    return _section(context, correctionsHeading, [
      for (var index = 0; index < proof.correctionLines.length; index++)
        _line(
          context,
          proof.correctionLines[index],
          keyName: 'proof_detail_correction_$index',
        ),
    ]);
  }

  /// A heading only ever exists alongside the body it introduces.
  List<Widget> _section(
    BuildContext context,
    String heading,
    List<Widget> body,
  ) => [_heading(context, heading), ...body, const SizedBox(height: 16)];

  Widget _heading(BuildContext context, String heading) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Semantics(
      header: true,
      label: heading,
      child: ExcludeSemantics(
        child: Text(heading, style: Theme.of(context).textTheme.titleSmall),
      ),
    ),
  );

  Widget _line(BuildContext context, String text, {required String keyName}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          key: Key(keyName),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );

  Widget _labelledEvidence(
    BuildContext context,
    String label,
    VerifiedProofEvidenceViewModel evidence, {
    required String keyName,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      _evidenceRow(context, evidence, keyName: keyName, semanticsPrefix: label),
    ],
  );

  Widget _evidenceRow(
    BuildContext context,
    VerifiedProofEvidenceViewModel evidence, {
    required String keyName,
    String? semanticsPrefix,
  }) {
    final theme = Theme.of(context);
    final date = formatEvidenceDate(evidence.sourceDate);
    final prefix = semanticsPrefix == null ? '' : '$semanticsPrefix. ';
    final callback = onOpenEvidence;
    return Semantics(
      container: true,
      button: callback != null,
      label: '${prefix}Moment from $date. ${evidence.quote}',
      onTap: callback == null ? null : () => callback(evidence.sourceEntryId),
      child: ExcludeSemantics(
        child: InkWell(
          key: Key(keyName),
          onTap: callback == null
              ? null
              : () => callback(evidence.sourceEntryId),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: minTapTarget,
              minWidth: minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '“${evidence.quote}”',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(date, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Shared so the compact card and this sheet never format a date differently.
  static String formatEvidenceDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';
}