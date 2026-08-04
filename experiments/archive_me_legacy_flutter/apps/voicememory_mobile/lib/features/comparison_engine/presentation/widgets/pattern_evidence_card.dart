import 'package:flutter/material.dart';

import '../../domain/models/archive_moment_record.dart';
import '../../domain/models/pattern_evidence_view_state.dart';

class PatternEvidenceCard extends StatelessWidget {
  const PatternEvidenceCard({
    super.key,
    required this.viewState,
    this.onProUpgradeTapped,
  });

  final PatternEvidenceViewState viewState;
  final VoidCallback? onProUpgradeTapped;

  static const changedPatternHighlight =
      'This pattern is changing. You noticed it earlier this time.';

  PatternState get state => viewState.state;
  String get connectionText => viewState.connectionText;
  String get pastQuote => viewState.pastQuote;
  String get currentQuote => viewState.currentQuote;
  String get whatChangedText => viewState.whatChangedText;
  bool get showProTrailPrompt => viewState.showProTrailPrompt;
  String? get conversionHeadline => viewState.conversionHeadline;

  @override
  Widget build(BuildContext context) {
    // Pure semantic colors mirroring the non-judgmental pattern state
    final themeColor = _getStateColor(state);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Archive Comparison',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStateLabel(state),
                    style: TextStyle(
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_showsGrowthHighlight(state)) ...[
              Container(
                key: const Key('pattern_evidence_growth_highlight'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      color: Colors.green,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        changedPatternHighlight,
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              connectionText,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Divider(height: 24),
            const Text(
              'THE EVIDENCE FROM YOUR WORDS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildQuoteBlock(
              key: const Key('pattern_evidence_past_quote'),
              label: 'PAST — YOUR WORDS',
              quote: pastQuote,
              accentColor: Colors.blueGrey,
              backgroundColor: Colors.blueGrey.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 10),
            _buildQuoteBlock(
              key: const Key('pattern_evidence_present_quote'),
              label: 'PRESENT — YOUR WORDS',
              quote: currentQuote,
              accentColor: themeColor,
              backgroundColor: themeColor.withValues(alpha: 0.1),
            ),
            const Divider(height: 24),
            const Text(
              'WHAT CHANGED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              whatChangedText,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
            if (conversionHeadline != null) ...[
              const SizedBox(height: 16),
              InkWell(
                key: const Key('pattern_evidence_pro_trail_prompt'),
                onTap: onProUpgradeTapped,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blueGrey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.blueGrey,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          conversionHeadline!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.blueGrey,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _showsGrowthHighlight(PatternState state) =>
      state == PatternState.softened ||
      state == PatternState.changed ||
      state == PatternState.corrected;

  Widget _buildQuoteBlock({
    required Key key,
    required String label,
    required String quote,
    required Color accentColor,
    required Color backgroundColor,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: accentColor,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '"$quote"',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              fontStyle: FontStyle.italic,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStateColor(PatternState state) {
    switch (state) {
      case PatternState.clearRepeat:
      case PatternState.stillCurrent:
        return Colors.blueGrey;
      case PatternState.softened:
      case PatternState.fading:
      case PatternState.corrected:
        return Colors.green;
      case PatternState.possibleRepeat:
      case PatternState.changed:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStateLabel(PatternState state) {
    switch (state) {
      case PatternState.earlySignal:
        return 'Early Signal';
      case PatternState.possibleRepeat:
        return 'Possible Repeat';
      case PatternState.clearRepeat:
        return 'Clear Repeat';
      case PatternState.stillCurrent:
        return 'Still Current';
      case PatternState.fading:
        return 'Fading';
      case PatternState.changed:
        return 'Changed';
      case PatternState.softened:
        return 'Softened';
      case PatternState.corrected:
        return 'Corrected';
      case PatternState.notEnoughEvidence:
        return 'Not Enough Evidence';
    }
  }
}
