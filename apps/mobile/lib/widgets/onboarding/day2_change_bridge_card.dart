import 'package:archiveme_mobile/widgets/retention/day2_return_reason_card.dart';
import 'package:flutter/material.dart';

/// Legacy wrapper — delegates to [Day2ReturnReasonCard].
class Day2ChangeBridgeCard extends StatelessWidget {
  const Day2ChangeBridgeCard({required this.onRecord, super.key});

  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Day2ReturnReasonCard(onRecord: onRecord);
  }
}