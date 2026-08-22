import 'package:archiveme_mobile/features/first_session_lift/first_session_lift_copy.dart';

class FirstSessionLiftChip {
  const FirstSessionLiftChip({required this.id, required this.text});

  final FirstSessionLiftChipId id;
  final String text;
}

class FirstSessionLiftResult {
  const FirstSessionLiftResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.microcopy,
    required this.chips,
    required this.entryCount,
    required this.source,
  });

  static const hidden = FirstSessionLiftResult(
    shouldShow: false,
    title: '',
    body: '',
    primaryCta: '',
    secondaryCta: '',
    microcopy: '',
    chips: [],
    entryCount: 0,
    source: '',
  );

  final bool shouldShow;
  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final String microcopy;
  final List<FirstSessionLiftChip> chips;
  final int entryCount;
  final String source;
}