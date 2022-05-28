namespace Axon\Tests\Unit;

use Axon\Cache\ARCCache;

final class TestARCCache {
  public static function run(): void {
    \printf("Running TestARCCache...\n");

    $arc = new ARCCache<string>(4);

    $arc->put('k1', 'val1');
    $arc->put('k2', 'val2');
    $arc->put('k3', 'val3');
    $arc->put('k4', 'val4');

    if ($arc->size() !== 4) {
      throw new \RuntimeException("ARC size should equal 4");
    }

    // Access k1 and k2 to promote to frequent list T2
    $arc->get('k1');
    $arc->get('k2');

    // Insert k5; should evict from recency list T1
    $arc->put('k5', 'val5');

    // k1 and k2 should still be resident
    if ($arc->get('k1') !== 'val1' || $arc->get('k2') !== 'val2') {
      throw new \RuntimeException("Frequent items should be preserved in ARC cache");
    }

    \printf("TestARCCache passed.\n");
  }
}
