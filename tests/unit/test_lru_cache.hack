namespace Axon\Tests\Unit;

use Axon\Cache\LRUCache;

final class TestLRUCache {
  public static function run(): void {
    \printf("Running TestLRUCache...\n");

    $cache = new LRUCache<string>(3);

    $cache->put('a', 'alpha');
    $cache->put('b', 'beta');
    $cache->put('c', 'gamma');

    if ($cache->size() !== 3) {
      throw new \RuntimeException("Expected cache size 3");
    }

    // Access 'a' to make it most recently used
    if ($cache->get('a') !== 'alpha') {
      throw new \RuntimeException("Failed to get 'a'");
    }

    // Adding 'd' should evict 'b' (since 'b' is now oldest)
    $cache->put('d', 'delta');

    if ($cache->get('b') !== null) {
      throw new \RuntimeException("'b' should have been evicted");
    }
    if ($cache->get('a') !== 'alpha' || $cache->get('c') !== 'gamma' || $cache->get('d') !== 'delta') {
      throw new \RuntimeException("Remaining keys should still be present");
    }

    // Test TTL expiration
    $cache->put('exp', 'expired', 1, 1, 1000);
    // Access at t = 3000ms (2 seconds later, exceeding 1s TTL)
    if ($cache->get('exp', 3000) !== null) {
      throw new \RuntimeException("Expired key should return null");
    }

    \printf("TestLRUCache passed.\n");
  }
}
