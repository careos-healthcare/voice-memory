import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_belief_providers.dart';

import '../../support/provider_test_harness.dart';

void main() {
  test('archive session mutations are explicit and reactive', () {
    final container = createTestProviderContainer();
    final revisions = <int>[];
    final subscription = container.listen(
      archiveSessionProvider,
      (previous, next) => revisions.add(next.revision),
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final controller = container.read(archiveSessionProvider.notifier);
    controller.dismissWorkspaceHint('intro');
    controller.dismissRetention();
    controller.refreshSurface();

    final state = container.read(archiveSessionProvider);
    expect(state.dismissedWorkspaceHints, {'intro'});
    expect(state.retentionDismissed, isTrue);
    expect(state.revision, 2);
    expect(revisions, [0, 1, 1, 2]);
  });
}
