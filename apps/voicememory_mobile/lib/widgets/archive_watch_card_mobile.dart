import 'package:flutter/material.dart';

import '../theme/voicememory_colors.dart';

class ArchiveWatchCardMobile extends StatelessWidget {
  const ArchiveWatchCardMobile({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.discoveryGoldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VoiceMemoryColors.discoveryGold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What To Watch',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: VoiceMemoryColors.discoveryGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            line,
            style: const TextStyle(
              color: VoiceMemoryColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
