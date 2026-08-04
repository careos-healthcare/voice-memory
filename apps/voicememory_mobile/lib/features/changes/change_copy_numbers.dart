const _numberWords = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
];

/// Small counts read as words in a sentence; larger ones stay as digits.
String spelledCount(int value) =>
    value >= 0 && value < _numberWords.length ? _numberWords[value] : '$value';
