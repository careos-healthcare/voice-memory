import 'package:archiveme_mobile/audio/pcm_chunk_queue_driver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enqueue and dequeue respect generation', () {
    final driver = PcmChunkQueueDriver();
    driver.enqueue(const [1, 2, 3]);
    final generation = driver.flushGeneration;

    expect(driver.dequeue(generation), [1, 2, 3]);
    expect(driver.dequeue(generation), isNull);
    expect(driver.queueDepth, 0);
  });

  test('flush clears queue and invalidates in-flight generation', () {
    final driver = PcmChunkQueueDriver();
    driver.enqueue(const [1, 2, 3, 4]);
    driver.enqueue(const [5, 6]);
    final staleGeneration = driver.flushGeneration;

    driver.flush();

    expect(driver.queueDepth, 0);
    expect(driver.activeQueueDepth, 0);
    expect(driver.dequeue(staleGeneration), isNull);
    expect(driver.flushGeneration, staleGeneration + 1);
  });

  test('setPlaying affects activeQueueDepth', () {
    final driver = PcmChunkQueueDriver();
    driver.enqueue(const [1, 2]);

    expect(driver.activeQueueDepth, 1);

    driver.setPlaying(true);
    expect(driver.activeQueueDepth, 2);

    driver.setPlaying(false);
    expect(driver.activeQueueDepth, 1);
  });

  test('dispose rejects further enqueue', () {
    final driver = PcmChunkQueueDriver();
    driver.dispose();

    driver.enqueue(const [1]);
    expect(driver.queueDepth, 0);
  });
}