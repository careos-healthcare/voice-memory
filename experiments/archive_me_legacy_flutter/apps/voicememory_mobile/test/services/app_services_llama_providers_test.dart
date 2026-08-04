import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/services/app_services_providers.dart';

void main() {
  test('test runtime exposes no live model plugin or session', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(llamaModelManagerProvider), isNull);
    expect(await container.read(llamaInferenceSessionProvider.future), isNull);
    await expectLater(
      container.read(llamaModelActionsProvider).optIn(),
      throwsStateError,
    );
  });
}
