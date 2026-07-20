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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            _buildQuoteBlock('Past', pastQuote, Colors.grey[700]!),
            const SizedBox(height: 8),
            _buildQuoteBlock('Present', currentQuote, Colors.black),
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

  Widget _buildQuoteBlock(String label, String quote, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          text: '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 13,
          ),
          children: [
            TextSpan(
              text: '"$quote"',
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: textColor,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ],
        ),
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
