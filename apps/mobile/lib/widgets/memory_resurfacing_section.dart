import 'package:archiveme_mobile/features/memory_resurfacing/memory_resurfacing_models.dart';
import 'package:flutter/material.dart';

/// Slivers for one resurfacing feed inside the archive home scroll view.
List<Widget> memoryResurfacingFeedSlivers({
  required String title,
  required List<MemoryResurfacingCardData> cards,
  required ValueChanged<MemoryResurfacingCardData> onCardTap,
  String? subtitle,
}) {
  if (cards.isEmpty) return const [];
  return [
    SliverToBoxAdapter(
      child: Text(subtitle == null ? title : '$title. $subtitle'),
    ),
  ];
}
