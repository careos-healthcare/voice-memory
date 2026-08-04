import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/first_proof_truth/first_proof_truth_analytics.dart';
import '../../features/first_proof_truth/first_proof_truth_copy.dart';
import '../../features/first_proof_truth/first_proof_truth_model.dart';
import '../../features/first_proof_truth/first_proof_truth_store.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Truth follow-up directly under first proof payoff — local answer only.
class FirstProofTruthCard extends StatefulWidget {
  const FirstProofTruthCard({
    super.key,
    required this.proofKey,
    required this.entryCount,
    required this.hasSnippets,
    this.store,
    this.skipPrefsLoad = false,
    this.initialAnswer,
    this.onAnswered,
  });

  const FirstProofTruthCard.test({
    super.key,
    required this.proofKey,
    required this.entryCount,
    required this.hasSnippets,
    this.store,
    this.initialAnswer,
    this.onAnswered,
  }) : skipPrefsLoad = true;

  final String proofKey;
  final int entryCount;
  final bool hasSnippets;
  final FirstProofTruthStore? store;
  final bool skipPrefsLoad;
  final FirstProofTruthAnswer? initialAnswer;
  final VoidCallback? onAnswered;

  @override
  State<FirstProofTruthCard> createState() => _FirstProofTruthCardState();
}

class _FirstProofTruthCardState extends State<FirstProofTruthCard> {
  FirstProofTruthStore? _store;
  FirstProofTruthAnswer? _answer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _answer = widget.initialAnswer;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    await FirstProofTruthStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _answer = FirstProofTruthStore.answerFor(widget.proofKey);
      _loading = false;
    });
  }

  Future<void> _select(FirstProofTruthAnswer answer) async {
    final answerKey = switch (answer) {
      FirstProofTruthAnswer.yes => 'yes',
      FirstProofTruthAnswer.sortOf => 'sort_of',
      FirstProofTruthAnswer.no => 'no',
    };
    FirstProofTruthAnalytics.answered(
      source: 'record',
      entryCount: widget.entryCount,
      answer: answerKey,
      hasSnippets: widget.hasSnippets,
    );
    if (!widget.skipPrefsLoad || widget.store != null) {
      _store ??= widget.store ?? FirstProofTruthStore.instance();
      await _store!.saveAnswer(proofKey: widget.proofKey, answer: answer);
    }
    if (!mounted) return;
    setState(() => _answer = answer);
    widget.onAnswered?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink(key: Key('first_proof_truth_loading'));
    }

    final answer = _answer;
    final showChoices = answer == null;

    if (answer != null) {
      return const SizedBox.shrink(key: Key('first_proof_truth_answered'));
    }

    return Container(
      key: const Key('first_proof_truth_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(background: const Color(0xFFF8FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showChoices) ...[
            Text(
              FirstProofTruthCopy.question,
              key: const Key('first_proof_truth_question'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              key: const Key('first_proof_truth_yes'),
              onPressed: () => _select(FirstProofTruthAnswer.yes),
              child: const Text(FirstProofTruthCopy.yesOption),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('first_proof_truth_sort_of'),
              onPressed: () => _select(FirstProofTruthAnswer.sortOf),
              child: const Text(FirstProofTruthCopy.sortOfOption),
            ),
            TextButton(
              key: const Key('first_proof_truth_no'),
              onPressed: () => _select(FirstProofTruthAnswer.no),
              child: const Text(FirstProofTruthCopy.noOption),
            ),
          ],
        ],
      ),
    );
  }
}
