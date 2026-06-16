import 'package:flutter/material.dart';

import '../../features/memory/entry_aboutness.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Shown after saving a hypothetical or not-about-me entry.
class NotAboutMeReceipt extends StatelessWidget {
  const NotAboutMeReceipt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('not_about_me_receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(),
      child: Text(
        EntryAboutnessCopy.nonPersonalReceipt,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
