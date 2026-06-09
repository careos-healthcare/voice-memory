import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/moments/moment_tag_engine.dart';

void main() {
  test('matches context keywords conservatively', () {
    expect(buildMomentTags('A long day at work and the meeting ran over.'),
        contains('work'));
    expect(buildMomentTags('I called my mum about the kids.'),
        contains('family'));
    expect(buildMomentTags('My partner and I disagreed.'), contains('partner'));
    expect(buildMomentTags('I met a friend for lunch.'), contains('friend'));
    expect(buildMomentTags('I worried about rent and money.'),
        containsAll(['money', 'worry']));
    expect(buildMomentTags('I could not sleep last night.'), contains('sleep'));
    expect(buildMomentTags('I felt pressure to say yes.'), contains('pressure'));
    expect(buildMomentTags('I was so tired and drained.'), contains('tired'));
    expect(buildMomentTags('I avoided the message all day.'),
        contains('avoided'));
  });

  test('adds result-driven tags from the hint, not the text', () {
    expect(buildMomentTags('A quiet day.', resultHint: 'lighter'),
        contains('lighter'));
    expect(buildMomentTags('A quiet day.', resultHint: 'heavier'),
        contains('heavier'));
    expect(buildMomentTags('A quiet day.', resultHint: 'changed'),
        contains('changed'));
    expect(buildMomentTags('A quiet day.', resultHint: 'none_fit'),
        contains('changed'));
  });

  test('does not overclaim on neutral text', () {
    expect(buildMomentTags('It was an ordinary morning.'), isEmpty);
  });

  test('caps at five tags', () {
    final tags = buildMomentTags(
      'At work my boss, my partner, a friend, and money worries left me '
      'tired and full of pressure.',
      resultHint: 'heavier',
    );
    expect(tags.length, lessThanOrEqualTo(5));
  });

  test('result tag is not duplicated when capped', () {
    final tags = buildMomentTags('work family partner friend money',
        resultHint: 'heavier', max: 5);
    expect(tags.length, 5);
    expect(tags.toSet().length, tags.length);
  });

  test('keeps deterministic enum order', () {
    final tags = buildMomentTags('I was tired at work.');
    expect(tags, ['work', 'tired']);
  });
}
