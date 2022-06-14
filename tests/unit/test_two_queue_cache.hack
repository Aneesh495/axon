namespace Axon\Tests\Unit;

use Axon\Cache\TwoQueueCache;

final class TestTwoQueueCache {
  public static function run(): void {
    \printf("Running TestTwoQueueCache...\n");

    $cache = new TwoQueueCache<string>(8);

    // Initial insertions into A1in
    $cache->put('item1', 'data1');
    $cache->put('item2', 'data2');

    if ($cache->get('item1') !== 'data1' || $cache->get('item2') !== 'data2') {
      throw new \RuntimeException("Failed to read from 2Q cache");
    }

    if ($cache->get('missing') !== null) {
      throw new \RuntimeException("Missing item should return null");
    }

    \printf("TestTwoQueueCache passed.\n");
  }
}
