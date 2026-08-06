import 'first_save_lift_copy.dart';

class FirstSaveLiftExample {
  const FirstSaveLiftExample({required this.id, required this.text});

  final FirstSaveLiftExampleId id;
  final String text;
}

class FirstSaveLiftResult {
  const FirstSaveLiftResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.examples,
    required this.entryCount,
    required this.source,
  });

  static const hidden = FirstSaveLiftResult(
    shouldShow: false,
    title: '',
    body: '',
    primaryCta: '',
    secondaryCta: '',
    examples: [],
    entryCount: 0,
    source: '',
  );

  final bool shouldShow;
  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final List<FirstSaveLiftExample> examples;
  final int entryCount;
  final String source;
}
