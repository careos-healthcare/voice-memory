import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/moments/key_moment_engine.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';

void main() {
  final date = DateTime(2026, 6, 5, 9, 30);

  test('preserves the original text exactly', () {
    const text =
        'I said yes before checking what I needed, even though I was '
        'tired.';
    final moment = buildKeyMoment(reflectionText: text, date: date);
    expect(moment.originalText, text);
  });

  test('title uses patternTitle when available', () {
    final moment = buildKeyMoment(
      reflectionText: 'After the meeting I carried it alone.',
      date: date,
      patternTitle: 'Taking on too much',
      resultHint: 'heavier',
    );
    expect(moment.title, 'Taking on too much');
    expect(moment.patternTitle, 'Taking on too much');
  });

  test('title falls back by resultHint when no pattern', () {
    expect(
      buildKeyMoment(reflectionText: 'x', date: date, resultHint: 'same').title,
      'A pattern showed up again',
    );
    expect(
      buildKeyMoment(
        reflectionText: 'x',
        date: date,
        resultHint: 'lighter',
      ).title,
      'Something felt lighter',
    );
    expect(
      buildKeyMoment(
        reflectionText: 'x',
        date: date,
        resultHint: 'heavier',
      ).title,
      'Something felt heavier',
    );
    expect(
      buildKeyMoment(
        reflectionText: 'x',
        date: date,
        resultHint: 'changed',
      ).title,
      'Something changed',
    );
  });

  test('title falls back to Moment from today with no hint', () {
    expect(
      buildKeyMoment(reflectionText: 'A quiet day.', date: date).title,
      'Moment from today',
    );
  });

  test('normalizes synonym result hints', () {
    expect(
      buildKeyMoment(
        reflectionText: 'x',
        date: date,
        resultHint: 'showed_up_again',
      ).resultHint,
      'same',
    );
    expect(
      buildKeyMoment(
        reflectionText: 'x',
        date: date,
        resultHint: 'none_fit',
      ).resultHint,
      'changed',
    );
  });

  test('short summary prefers a sentence with a moment cue', () {
    final moment = buildKeyMoment(
      reflectionText:
          'It was a long day. The worry came back when things '
          'got quiet.',
      date: date,
    );
    expect(moment.shortSummary, 'The worry came back when things got quiet.');
  });

  test('tags are conservative and keyword-driven', () {
    final moment = buildKeyMoment(
      reflectionText:
          'I felt pressure and was tired after the meeting '
          'with my boss.',
      date: date,
      resultHint: 'heavier',
    );
    expect(moment.tags, contains('pressure'));
    expect(moment.tags, contains('tired'));
    expect(moment.tags, contains('work'));
    expect(moment.tags, contains('heavier'));
    // The removed legacy "relationship" tag is no longer produced.
    expect(moment.tags, isNot(contains('relationship')));
  });

  test('plain result label maps hints to consumer copy', () {
    expect(keyMomentResultLabel('same'), 'showed up again');
    expect(keyMomentResultLabel('lighter'), 'felt lighter');
    expect(keyMomentResultLabel('heavier'), 'felt heavier');
    expect(keyMomentResultLabel('changed'), 'changed');
    expect(keyMomentResultLabel(null), isNull);
  });

  test('round-trips through json', () {
    final moment = buildKeyMoment(
      reflectionText: 'After lunch I avoided the message.',
      date: date,
      patternTitle: 'Avoiding hard messages',
      resultHint: 'same',
      nextCheck: 'What pressure showed up before you delayed it?',
      languageCode: 'en',
      source: KeyMomentSource.checkIn,
    );
    final restored = KeyMoment.fromJson(moment.toJson());
    expect(restored, isNotNull);
    expect(restored!.originalText, moment.originalText);
    expect(restored.title, moment.title);
    expect(restored.nextCheck, moment.nextCheck);
    expect(restored.source, KeyMomentSource.checkIn);
    expect(restored.tags, moment.tags);
  });
}
