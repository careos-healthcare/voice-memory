import 'package:flutter_test/flutter_test.dart';
import 'support/test_storage_sandbox.dart';

void main() {
  test('rejects paths outside sandbox root', () {
    final sandbox = TestStorageSandbox.create();
    addTearDown(sandbox.dispose);
    expect(() => sandbox.path('../escape.json'), throwsArgumentError);
    expect(() => sandbox.path('/etc/passwd'), throwsArgumentError);
  });

  test('exposes journal prefs recovery and output paths inside root', () {
    final sandbox = TestStorageSandbox.create();
    addTearDown(sandbox.dispose);
    for (final candidate in [
      sandbox.journalPath,
      sandbox.prefsPath,
      sandbox.recoveryPath,
      sandbox.outputPath,
    ]) {
      expect(candidate.startsWith(sandbox.root.path), isTrue);
    }
  });

  test('deterministic clock and ids are injectable', () {
    final fixed = DateTime.utc(2024, 6);
    final sandbox = TestStorageSandbox.create(
      clock: TestClock(fixed),
      ids: TestIds(),
    );
    addTearDown(sandbox.dispose);
    expect(sandbox.clock.now, fixed);
    expect(sandbox.ids.next(), 'test-id-0');
    expect(sandbox.ids.next('entry'), 'entry-1');
  });

  test('dispose removes sandbox root', () async {
    final sandbox = TestStorageSandbox.create();
    final root = sandbox.root;
    expect(root.existsSync(), isTrue);
    await sandbox.dispose();
    expect(root.existsSync(), isFalse);
  });
}