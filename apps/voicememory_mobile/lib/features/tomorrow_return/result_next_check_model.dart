/// The kind of next check a closed loop points toward.
enum ResultNextCheckType {
  repeatBefore,
  findHelped,
  reduceHeavier,
  noticeDifferent,
  makeConcrete,
}

extension ResultNextCheckTypeIds on ResultNextCheckType {
  String get id => name;
}

/// One useful thing to check next after a loop closes.
///
/// This turns a result into a clear next action: what to check, why it helps,
/// and the exact question to carry into tomorrow.
class ResultNextCheck {
  const ResultNextCheck({
    required this.type,
    required this.title,
    required this.whyUseful,
    required this.nextQuestion,
    required this.exampleMoment,
    required this.ctaLabel,
  });

  final ResultNextCheckType type;
  final String title;
  final String whyUseful;
  final String nextQuestion;
  final String exampleMoment;
  final String ctaLabel;
}
