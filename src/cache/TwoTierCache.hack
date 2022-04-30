namespace Axon\Cache;

/**
 * TwoTierCache combines request-scoped L1 cache with a shared L2 LRU/ARC cache.
 */
final class TwoTierCache<T> {
  private LRUCache<T> $l1;
  private LRUCache<T> $l2;

  public function __construct(int $l1Capacity = 256, int $l2Capacity = 4096) {
    $this->l1 = new LRUCache<T>($l1Capacity);
    $this->l2 = new LRUCache<T>($l2Capacity);
  }

  public function get(string $key, int $nowMs = 0): ?T {
    // 1. Try L1 fast local cache
    $val = $this->l1->get($key, $nowMs);
    if ($val !== null) {
      return $val;
    }

    // 2. Try L2 shared cache
    $val = $this->l2->get($key, $nowMs);
    if ($val !== null) {
      // Promote into L1 for subsequent request hits
      $this->l1->put($key, $val, 0, 1, $nowMs);
      return $val;
    }

    return null;
  }

  public function put(
    string $key,
    T $value,
    int $ttlSeconds = 0,
    int $version = 1,
    int $nowMs = 0
  ): void {
    $this->l1->put($key, $value, $ttlSeconds, $version, $nowMs);
    $this->l2->put($key, $value, $ttlSeconds, $version, $nowMs);
  }

  public function invalidate(string $key): void {
    $this->l1->delete($key);
    $this->l2->delete($key);
  }

  public function resetL1(): void {
    $this->l1->clear();
  }

  public function clearAll(): void {
    $this->l1->clear();
    $this->l2->clear();
  }
}
