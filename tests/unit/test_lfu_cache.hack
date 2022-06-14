namespace Axon\Tests\Unit;

use Axon\Cache\LFUCache;

final class TestLFUCache {
  public static function run(): void {
    \printf("Running TestLFUCache...\n");

    $lfu = new LFUCache<string>(3);

    $lfu->put('a', 'alpha');
    $lfu->put('b', 'beta');
    $lfu->put('c', 'gamma');

    // Access 'a' three times, 'b' two times, 'c' one time
    $lfu->get('a');
    $lfu->get('a');
    $lfu->get('b');

    // Inserting 'd' should evict 'c' because 'c' has lowest frequency (1)
    $lfu->put('d', 'delta');

    if ($lfu->get('c') !== null) {
      throw new \RuntimeException("'c' should have been evicted by LFU policy");
    }
    if ($lfu->get('a') !== 'alpha' || $lfu->get('b') !== 'beta' || $lfu->get('d') !== 'delta') {
      throw new \RuntimeException("Remaining items should be accessible");
    }

    \printf("TestLFUCache passed.\n");
  }
}
