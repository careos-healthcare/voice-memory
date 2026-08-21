import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Discover Yourself section accents — icon + label color coding.
enum DiscoverSectionKind {
  belief,
  beliefChanges,
  themes,
  contradictions,
  blindSpots,
  chapters,
  askArchive,
  weeklyStory,
}

class DiscoverSectionStyle {
  const DiscoverSectionStyle({required this.accent, required this.icon});

  final Color accent;
  final IconData icon;

  static DiscoverSectionStyle forKind(DiscoverSectionKind kind) =>
      switch (kind) {
        DiscoverSectionKind.belief => const DiscoverSectionStyle(
          accent: VoiceMemoryColors.beliefIndigo,
          icon: Icons.psychology_outlined,
        ),
        DiscoverSectionKind.beliefChanges => const DiscoverSectionStyle(
          accent: VoiceMemoryColors.beliefChangeGold,
          icon: Icons.trending_up,
        ),
        DiscoverSectionKind.themes => const DiscoverSectionStyle(
          accent: VoiceMemoryColors.themeLavender,
          icon: Icons.hub_outlined,
        ),
        DiscoverSectionKind.contradictions => const DiscoverSectionStyle(
          accent: VoiceMemoryColors.contradictionRose,
          icon: Icons.compare_arrows,
        ),
        DiscoverSectionKind.blindSpots => const DiscoverSectionStyle(
          accent: VoiceMemoryColors.blindSpotAmber,
          icon: Icons.visibility_off_outlined,
        ),
        DiscoverSectionKind.chapters => const DiscoverSectionStyle(
          accent: VoiceMemoryColors.chapterBlue,
          icon: Icons.menu_book_outlined,
        ),
        DiscoverSectionKind.askArchive => const DiscoverSectionStyle(
          accent: VoiceMemoryColors.primaryIndigo,
          icon: Icons.chat_bubble_outline,
        ),
        DiscoverSectionKind.weeklyStory => const DiscoverSectionStyle(
          accent: VoiceMemoryColors.discoveryGold,
          icon: Icons.auto_stories_outlined,
        ),
      };
}