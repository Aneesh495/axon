namespace Axon\Cache;

/**
 * Adaptive Replacement Cache (ARC).
 * Dynamically self-tunes between recency and frequency using four LRU lists:
 * - T1: Recent cache hits (resident)
 * - B1: Recent ghost history (keys only)
 * - T2: Frequent cache hits (resident)
 * - B2: Frequent ghost history (keys only)
 */
final class ARCCache<T> {
  private int $c; // Target capacity
  private float $p; // Adaptation tuning parameter

  private dict<string, CacheEntry<T>> $t1;
  private dict<string, bool> $b1;
  private dict<string, CacheEntry<T>> $t2;
  private dict<string, bool> $b2;

  private int $hits;
  private int $misses;

  public function __construct(int $capacity = 1024) {
    if ($capacity <= 0) {
      throw new \InvalidArgumentException('Capacity must be positive');
    }
    $this->c = $capacity;
    $this->p = 0.0;
    $this->t1 = dict[];
    $this->b1 = dict[];
    $this->t2 = dict[];
    $this->b2 = dict[];
    $this->hits = 0;
    $this->misses = 0;
  }

  public function get(string $key, int $nowMs = 0): ?T {
    // Case 1: Key is resident in T1
    if (\array_key_exists($key, $this->t1)) {
      $entry = $this->t1[$key];
      unset($this->t1[$key]);
      if ($entry->isExpired($nowMs)) {
        $this->misses++;
        return null;
      }
      $entry->recordAccess($nowMs);
      $this->t2[$key] = $entry;
      $this->hits++;
      return $entry->getValue();
    }

    // Case 2: Key is resident in T2
    if (\array_key_exists($key, $this->t2)) {
      $entry = $this->t2[$key];
      unset($this->t2[$key]);
      if ($entry->isExpired($nowMs)) {
        $this->misses++;
        return null;
      }
      $entry->recordAccess($nowMs);
      $this->t2[$key] = $entry;
      $this->hits++;
      return $entry->getValue();
    }

    $this->misses++;
    return null;
  }

  public function put(
    string $key,
    T $value,
    int $ttlSeconds = 0,
    int $version = 1,
    int $nowMs = 0
  ): void {
    $entry = new CacheEntry<T>($key, $value, $ttlSeconds, $version, $nowMs);

    // Case 1: Key already exists in T1 or T2
    if (\array_key_exists($key, $this->t1)) {
      unset($this->t1[$key]);
      $this->t2[$key] = $entry;
      return;
    }
    if (\array_key_exists($key, $this->t2)) {
      unset($this->t2[$key]);
      $this->t2[$key] = $entry;
      return;
    }

    // Case 2: Key is in ghost history B1 (favour recency)
    if (\array_key_exists($key, $this->b1)) {
      $delta = \count($this->b1) >= \count($this->b2)
        ? 1.0
        : (float)\count($this->b2) / (float)\max(1, \count($this->b1));
      $this->p = \min((float)$this->c, $this->p + $delta);

      $this->replace($key);
      unset($this->b1[$key]);
      $this->t2[$key] = $entry;
      return;
    }

    // Case 3: Key is in ghost history B2 (favour frequency)
    if (\array_key_exists($key, $this->b2)) {
      $delta = \count($this->b2) >= \count($this->b1)
        ? 1.0
        : (float)\count($this->b1) / (float)\max(1, \count($this->b2));
      $this->p = \max(0.0, $this->p - $delta);

      $this->replace($key);
      unset($this->b2[$key]);
      $this->t2[$key] = $entry;
      return;
    }

    // Case 4: Complete cache miss (neither resident nor in ghost history)
    $lenL1 = \count($this->t1) + \count($this->b1);
    if ($lenL1 === $this->c) {
      if (\count($this->t1) < $this->c) {
        $this->evictOldestKey($this->b1);
        $this->replace($key);
      } else {
        $this->evictOldestEntry($this->t1);
      }
    } else if ($lenL1 < $this->c) {
      $total = $lenL1 + \count($this->t2) + \count($this->b2);
      if ($total >= $this->c) {
        if ($total === 2 * $this->c) {
          $this->evictOldestKey($this->b2);
        }
        $this->replace($key);
      }
    }

    $this->t1[$key] = $entry;
  }

  private function replace(string $key): void {
    $t1Count = \count($this->t1);
    if ($t1Count > 0 && ((float)$t1Count > $this->p || (\array_key_exists($key, $this->b2) && (float)$t1Count === $this->p))) {
      // Evict from T1 into ghost history B1
      $oldest = $this->popOldestEntry($this->t1);
      if ($oldest !== null) {
        $this->b1[$oldest->getKey()] = true;
      }
    } else {
      // Evict from T2 into ghost history B2
      $oldest = $this->popOldestEntry($this->t2);
      if ($oldest !== null) {
        $this->b2[$oldest->getKey()] = true;
      }
    }
  }

  private function popOldestEntry(dict<string, CacheEntry<T>> &$d): ?CacheEntry<T> {
    foreach ($d as $k => $entry) {
      unset($d[$k]);
      return $entry;
    }
    return null;
  }

  private function evictOldestEntry(dict<string, CacheEntry<T>> &$d): void {
    foreach ($d as $k => $_) {
      unset($d[$k]);
      return;
    }
  }

  private function evictOldestKey(dict<string, bool> &$d): void {
    foreach ($d as $k => $_) {
      unset($d[$k]);
      return;
    }
  }

  public function size(): int {
    return \count($this->t1) + \count($this->t2);
  }

  public function getCapacity(): int {
    return $this->c;
  }

  public function getHitRatio(): float {
    $total = $this->hits + $this->misses;
    return $total === 0 ? 0.0 : (float)$this->hits / (float)$total;
  }

  public function clear(): void {
    $this->t1 = dict[];
    $this->b1 = dict[];
    $this->t2 = dict[];
    $this->b2 = dict[];
    $this->p = 0.0;
  }
}
