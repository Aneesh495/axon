namespace Axon\Cache;

/**
 * 2Q (Two-Queue) Cache.
 * Solves the single-access scan pollution problem of LRU by using:
 * - A1in: FIFO queue for initial items
 * - A1out: FIFO queue holding ghost keys of recently evicted A1in items
 * - Am: LRU queue for items accessed more than once
 */
final class TwoQueueCache<T> {
  private int $capacity;
  private int $kin;
  private int $kout;

  private dict<string, CacheEntry<T>> $a1in;
  private dict<string, bool> $a1out;
  private LRUCache<T> $am;

  public function __construct(int $capacity = 1024) {
    $this->capacity = \max(4, $capacity);
    $this->kin = \max(1, (int)($this->capacity * 0.25));
    $this->kout = \max(1, (int)($this->capacity * 0.50));

    $this->a1in = dict[];
    $this->a1out = dict[];
    $this->am = new LRUCache<T>($this->capacity);
  }

  public function get(string $key, int $nowMs = 0): ?T {
    // 1. Check Am (frequent LRU)
    $val = $this->am->get($key, $nowMs);
    if ($val !== null) {
      return $val;
    }

    // 2. Check A1in (recent FIFO)
    if (\array_key_exists($key, $this->a1in)) {
      $entry = $this->a1in[$key];
      if ($entry->isExpired($nowMs)) {
        unset($this->a1in[$key]);
        return null;
      }
      return $entry->getValue();
    }

    return null;
  }

  public function put(string $key, T $value, int $ttlSeconds = 0, int $version = 1, int $nowMs = 0): void {
    // 1. If key is in Am, update Am
    if ($this->am->get($key, $nowMs) !== null) {
      $this->am->put($key, $value, $ttlSeconds, $version, $nowMs);
      return;
    }

    // 2. If key is in A1out (ghost history), promote to Am
    if (\array_key_exists($key, $this->a1out)) {
      unset($this->a1out[$key]);
      $this->am->put($key, $value, $ttlSeconds, $version, $nowMs);
      return;
    }

    // 3. If key is in A1in, update value in place
    if (\array_key_exists($key, $this->a1in)) {
      $this->a1in[$key] = new CacheEntry<T>($key, $value, $ttlSeconds, $version, $nowMs);
      return;
    }

    // 4. Key is completely new: insert into A1in
    if (\count($this->a1in) >= $this->kin) {
      // Evict oldest from A1in into A1out ghost history
      $oldestKey = null;
      foreach ($this->a1in as $k => $_) {
        $oldestKey = $k;
        break;
      }
      if ($oldestKey !== null) {
        unset($this->a1in[$oldestKey]);
        if (\count($this->a1out) >= $this->kout) {
          $oldestGhost = null;
          foreach ($this->a1out as $gk => $_) {
            $oldestGhost = $gk;
            break;
          }
          if ($oldestGhost !== null) {
            unset($this->a1out[$oldestGhost]);
          }
        }
        $this->a1out[$oldestKey] = true;
      }
    }

    $this->a1in[$key] = new CacheEntry<T>($key, $value, $ttlSeconds, $version, $nowMs);
  }

  public function size(): int {
    return \count($this->a1in) + $this->am->size();
  }

  public function clear(): void {
    $this->a1in = dict[];
    $this->a1out = dict[];
    $this->am->clear();
  }
}
