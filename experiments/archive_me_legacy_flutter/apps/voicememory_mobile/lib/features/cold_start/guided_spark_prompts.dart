import 'package:flutter/material.dart';

import 'cold_start_engine.dart';

class GuidedSparkPrompt {
  const GuidedSparkPrompt({
    required this.day,
    required this.prompt,
    this.relatedSeedLabels = const [],
  });

  final int day;
  final String prompt;
  final List<String> relatedSeedLabels;
}

abstract final class GuidedSparkPrompts {
  static const maxEntryCount = 7;

  static GuidedSparkPrompt? forEntryCount(
    int entryCount, {
    ColdStartSeedData? seed,
  }) {
    if (entryCount >= maxEntryCount) return null;
    if (entryCount == 0) {
      return const GuidedSparkPrompt(
        day: 1,
        prompt: 'Introduce your current season of life in 30 seconds.',
      );
    }
    if (entryCount == 1) {
      return const GuidedSparkPrompt(
        day: 2,
        prompt: 'What is working well right now, and what feels stuck?',
      );
    }
    final person = seed?.people.firstOrNull;
    return GuidedSparkPrompt(
      day: 3,
      prompt: person == null
          ? 'Talk about one important person in your world right now.'
          : 'Talk about $person and what feels important in that relationship.',
      relatedSeedLabels: person == null ? const [] : [person],
    );
  }
}

class SparkCard extends StatelessWidget {
  const SparkCard({super.key, required this.spark, required this.onSelected});

  final GuidedSparkPrompt spark;
  final ValueChanged<GuidedSparkPrompt> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Day ${spark.day} Spark prompt. ${spark.prompt}',
    child: Card(
      key: Key('guided_spark_card_day_${spark.day}'),
      child: InkWell(
        onTap: () => onSelected(spark),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${spark.day} Spark',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(spark.prompt),
                  ],
                ),
              ),
              const Icon(Icons.mic_none),
            ],
          ),
        ),
      ),
    ),
  );
}
