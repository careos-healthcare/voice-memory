import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('archive belief screen uses lazy sliver list for entries', () {
    final source = File(
      'lib/screens/archive_belief_screen.dart',
    ).readAsStringSync();
    expect(source, contains('CustomScrollView'));
    expect(source, contains('SliverList'));
    expect(source, contains('SliverChildBuilderDelegate'));
    expect(source, isNot(contains('for (final entry in')));
    expect(source, contains('archiveFeedPaginationProvider'));
    expect(source, contains('ArchiveEntryCard'));
  });
}