/// Pricing offer validation copy — beta intent collection only, no purchase changes.
abstract final class PricingOfferValidationV2Copy {
  PricingOfferValidationV2Copy._();

  static const title = 'Is the longer trail worth keeping?';

  static const body =
      'Free shows the first useful proof. Pro keeps tracking whether that repeat '
      'returns, changes, fades, or gets corrected.';

  static const valueLine =
      'You are not paying for more AI. You are paying to keep the evidence trail '
      'over time.';

  static const priceQuestion = 'Would you pay to keep that longer trail?';

  static const priceYes = 'Yes';
  static const priceMaybe = 'Maybe';
  static const priceNo = 'No';

  static const reasonQuestion = 'What would make this worth paying for?';

  static const reasonSeeingReturn = 'Seeing it return over time';
  static const reasonSeeingChanges = 'Seeing whether it changes';
  static const reasonCorrectIt = 'Being able to correct it';
  static const reasonStrongerProof = 'I need stronger proof first';
  static const reasonRanking = 'I would need ranking';
  static const reasonPriceTooHigh = 'Price feels too high';

  static const cta = 'See Pro';

  static const secondary = 'Keep using free';

  static const guardrail =
      'Do not add ranking unless pricing fails specifically because users '
      'understand the trail but say they need prioritisation to pay.';

  static const bannedPhrases = [
    'ranked list',
    'importance score',
    'more ai',
    'better advice',
    'coaching',
    'therapy',
    'diagnosis',
    'generic journaling',
    'you should',
    'you need to',
  ];

  static const priceOptions = [
    priceYes,
    priceMaybe,
    priceNo,
  ];

  static const reasonOptions = [
    reasonSeeingReturn,
    reasonSeeingChanges,
    reasonCorrectIt,
    reasonStrongerProof,
    reasonRanking,
    reasonPriceTooHigh,
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield valueLine;
    yield priceQuestion;
    yield priceYes;
    yield priceMaybe;
    yield priceNo;
    yield reasonQuestion;
    yield reasonSeeingReturn;
    yield reasonSeeingChanges;
    yield reasonCorrectIt;
    yield reasonStrongerProof;
    yield reasonRanking;
    yield reasonPriceTooHigh;
    yield cta;
    yield secondary;
    yield guardrail;
  }
}
