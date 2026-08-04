import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/input_quality/input_quality_model.dart';
import '../../features/language/localized_copy.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Coaches a weak/vague reflection toward one concrete moment before a pattern
/// or result is generated. Shows one sharpening prompt per reflection.
class InputQualityCoachCard extends StatefulWidget {
  const InputQualityCoachCard({
    super.key,
    required this.result,
    required this.originalText,
    required this.onAddSentence,
    required this.onUseAnyway,
    this.languageCode = 'en',
  });

  final InputQualityResult result;
  final String originalText;

  /// Detected/selected reflection language. Non-English localizes the coach
  /// title, body, and buttons; English is unchanged.
  final String languageCode;

  /// Called with the combined original + added sentence.
  final Future<void> Function(String combinedText) onAddSentence;

  /// Called when the user keeps the original weak input.
  final VoidCallback onUseAnyway;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  State<InputQualityCoachCard> createState() => _InputQualityCoachCardState();
}

class _InputQualityCoachCardState extends State<InputQualityCoachCard> {
  final TextEditingController _controller = TextEditingController();
  bool _expanded = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackInputQualityCoachShown();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSubmitSentence() async {
    final added = _controller.text.trim();
    if (added.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    ActivationTracker.trackInputQualitySentenceAdded();
    final combined = '${widget.originalText.trim()} $added'.trim();
    await widget.onAddSentence(combined);
  }

  void _onUseAnyway() {
    ActivationTracker.trackInputQualityUsedAnyway();
    widget.onUseAnyway();
  }

  String _t(String key, String enValue) => widget.languageCode == 'en'
      ? enValue
      : localized(key, widget.languageCode);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: InputQualityCoachCard._warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: InputQualityCoachCard._warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('inputQualityCoachTitle', ConsumerUiCopy.inputQualityCoachTitle),
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _t('inputQualityCoachBody', ConsumerUiCopy.inputQualityCoachBody),
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.result.helpfulPrompt,
            style: VoiceMemoryTypography.bodyStyle().copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_t('exampleLabel', ConsumerUiCopy.inputQualityCoachExampleLabel)}: '
            '${widget.result.exampleRewrite}',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_expanded) ...[
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onSubmitSentence(),
              decoration: InputDecoration(
                hintText: _t(
                  'addSentenceHint',
                  ConsumerUiCopy.inputQualityCoachAddSentenceHint,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: InputQualityCoachCard._warmBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: InputQualityCoachCard._warmBorder,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _submitting
                  ? null
                  : (_expanded
                        ? _onSubmitSentence
                        : () => setState(() => _expanded = true)),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _t(
                        'addOneSentence',
                        ConsumerUiCopy.inputQualityCoachAddSentenceCta,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _submitting ? null : _onUseAnyway,
              child: Text(
                _t('useItAnyway', ConsumerUiCopy.inputQualityCoachUseAnywayCta),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
