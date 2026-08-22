import 'package:archiveme_mobile/features/belief_evidence/ui/fact_ledger_resolved_citation.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/source_citation_indicator.dart';
import 'package:flutter/material.dart';

/// Claim copy with an always-visible inline source-count indicator.
class CitedClaimText extends StatelessWidget {
  const CitedClaimText({
    required this.text,
    required this.citations,
    super.key,
    this.style,
    this.claimContext,
    this.indicatorSuffix = 'claim',
  });

  final String text;
  final List<FactLedgerResolvedCitation> citations;
  final TextStyle? style;
  final String? claimContext;
  final String indicatorSuffix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(text, style: style),
        SourceCitationIndicator(
          key: SourceCitationIndicator.indicatorKeyFor(indicatorSuffix),
          citations: citations,
          claimContext: claimContext ?? text,
        ),
      ],
    );
  }
}
