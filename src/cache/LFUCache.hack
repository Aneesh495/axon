namespace Axon\Cache;

/**
 * LFU Node holding key, value, and access frequency.
 */
final class LFUNode<T> {
  public string $key;
  public T $value;
  public int $freq;

  public function __construct(string $key, T $value) {
    $this->key = $key;
    $this->value = $value;
    $this->freq = 1;
  }
}

/**
 * LFUCache: O(1) Least Frequently Used cache.
 * Evicts keys with the lowest access frequency count when capacity is reached.
 */
final class LFUCache<T> {
  private int $capacity;
  private dict<string, LFUNode<T>> $keyTable;
  private dict<int, keyset<string>> $freqTable;
  private int $minFreq;

  public function __construct(int $capacity = 1024) {
    if ($capacity <= 0) {
      throw new \InvalidArgumentException('Capacity must be positive');
    }
    $this->capacity = $capacity;
    $this->keyTable = dict[];
    $this->freqTable = dict[];
    $this->minFreq = 0;
  }

  public function get(string $key): ?T {
    if (!\array_key_exists($key, $this->keyTable)) {
      return null;
    }

    $node = $this->keyTable[$key];
    $this->incrementFreq($node);
    return $node->value;
  }

  public function put(string $key, T $value): void {
    if (\array_key_exists($key, $this->keyTable)) {
      $node = $this->keyTable[$key];
      $node->value = $value;
      $this->incrementFreq($node);
      return;
    }

    if (\count($this->keyTable) >= $this->capacity) {
      $this->evictMinFreq();
    }

    $node = new LFUNode<T>($key, $value);
    $this->keyTable[$key] = $node;

    if (!\array_key_exists(1, $this->freqTable)) {
      $this->freqTable[1] = keyset[];
    }
    $set = $this->freqTable[1];
    $set[] = $key;
    $this->freqTable[1] = $set;
    $this->minFreq = 1;
  }

  private function incrementFreq(LFUNode<T> $node): void {
    $oldFreq = $node->freq;
    $newFreq = $oldFreq + 1;
    $node->freq = $newFreq;

    // Remove from old freq set
    if (\array_key_exists($oldFreq, $this->freqTable)) {
      $filtered = keyset[];
      foreach ($this->freqTable[$oldFreq] as $k) {
        if ($k !== $node->key) {
          $filtered[] = $k;
        }
      }
      $this->freqTable[$oldFreq] = $filtered;
      if (\count($filtered) === 0 && $this->minFreq === $oldFreq) {
        $this->minFreq = $newFreq;
      }
    }

    // Add to new freq set
    if (!\array_key_exists($newFreq, $this->freqTable)) {
      $this->freqTable[$newFreq] = keyset[];
    }
    $set = $this->freqTable[$newFreq];
    $set[] = $node->key;
    $this->freqTable[$newFreq] = $set;
  }

  private function evictMinFreq(): void {
    if (!\array_key_exists($this->minFreq, $this->freqTable) || \count($this->freqTable[$this->minFreq]) === 0) {
      return;
    }

    $evictedKey = null;
    foreach ($this->freqTable[$this->minFreq] as $k) {
      $evictedKey = $k;
      break;
    }

    if ($evictedKey !== null) {
      $filtered = keyset[];
      foreach ($this->freqTable[$this->minFreq] as $k) {
        if ($k !== $evictedKey) {
          $filtered[] = $k;
        }
      }
      $this->freqTable[$this->minFreq] = $filtered;
      unset($this->keyTable[$evictedKey]);
    }
  }

  public function size(): int {
    return \count($this->keyTable);
  }

  public function clear(): void {
    $this->keyTable = dict[];
    $this->freqTable = dict[];
    $this->minFreq = 0;
  }
}
