import 'package:archiveme_mobile/features/archive/controllers/on_this_day_controller.dart';
import 'package:flutter/material.dart';

/// Shown when this calendar day has no earlier memories left to show.
class OnThisDayEmptySection extends StatelessWidget {
  const OnThisDayEmptySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('on_this_day_empty'),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          OnThisDayController.emptyCopy,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
