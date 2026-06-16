import 'package:flutter/material.dart';

import '../retention/day2_return_reason_card.dart';

/// Legacy wrapper — delegates to [Day2ReturnReasonCard].
class Day2ChangeBridgeCard extends StatelessWidget {
  const Day2ChangeBridgeCard({super.key, required this.onRecord});

  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Day2ReturnReasonCard(onRecord: onRecord, source: 'record');
  }
}
