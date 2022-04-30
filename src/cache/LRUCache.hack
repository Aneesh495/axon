namespace Axon\Cache;

/**
 * Node in doubly-linked list for O(1) LRU eviction order tracking.
 */
final class LRUNode<T> {
  public string $key;
  public CacheEntry<T> $entry;
  public ?LRUNode<T> $prev;
  public ?LRUNode<T> $next;

  public function __construct(string $key, CacheEntry<T> $entry) {
    $this->key = $key;
    $this->entry = $entry;
    $this->prev = null;
    $this->next = null;
  }
}

/**
 * LRUCache provides constant-time O(1) reads, insertions, and evictions
 * with configurable maximum capacity and per-entry TTL support.
 */
final class LRUCache<T> {
  private int $capacity;
  private dict<string, LRUNode<T>> $lookup;
  private ?LRUNode<T> $head;
  private ?LRUNode<T> $tail;
  private int $hitCount;
  private int $missCount;

  public function __construct(int $capacity = 1024) {
    if ($capacity <= 0) {
      throw new \InvalidArgumentException('Capacity must be strictly positive');
    }
    $this->capacity = $capacity;
    $this->lookup = dict[];
    $this->head = null;
    $this->tail = null;
    $this->hitCount = 0;
    $this->missCount = 0;
  }

  public function get(string $key, int $nowMs = 0): ?T {
    if (!\array_key_exists($key, $this->lookup)) {
      $this->missCount++;
      return null;
    }

    $node = $this->lookup[$key];
    if ($node->entry->isExpired($nowMs)) {
      $this->removeNode($node);
      unset($this->lookup[$key]);
      $this->missCount++;
      return null;
    }

    $node->entry->recordAccess($nowMs);
    $this->moveToHead($node);
    $this->hitCount++;
    return $node->entry->getValue();
  }

  public function put(string $key, T $value, int $ttlSeconds = 0, int $version = 1, int $nowMs = 0): void {
    if (\array_key_exists($key, $this->lookup)) {
      $node = $this->lookup[$key];
      $node->entry = new CacheEntry<T>($key, $value, $ttlSeconds, $version, $nowMs);
      $this->moveToHead($node);
      return;
    }

    if (\count($this->lookup) >= $this->capacity) {
      $this->evictOldest();
    }

    $entry = new CacheEntry<T>($key, $value, $ttlSeconds, $version, $nowMs);
    $node = new LRUNode<T>($key, $entry);
    $this->lookup[$key] = $node;
    $this->addToHead($node);
  }

  public function delete(string $key): void {
    if (\array_key_exists($key, $this->lookup)) {
      $node = $this->lookup[$key];
      $this->removeNode($node);
      unset($this->lookup[$key]);
    }
  }

  public function clear(): void {
    $this->lookup = dict[];
    $this->head = null;
    $this->tail = null;
  }

  public function size(): int {
    return \count($this->lookup);
  }

  public function getCapacity(): int {
    return $this->capacity;
  }

  public function getHitCount(): int {
    return $this->hitCount;
  }

  public function getMissCount(): int {
    return $this->missCount;
  }

  public function getHitRatio(): float {
    $total = $this->hitCount + $this->missCount;
    return $total === 0 ? 0.0 : (float)$this->hitCount / (float)$total;
  }

  private function addToHead(LRUNode<T> $node): void {
    $node->prev = null;
    $node->next = $this->head;

    if ($this->head !== null) {
      $this->head->prev = $node;
    }
    $this->head = $node;

    if ($this->tail === null) {
      $this->tail = $node;
    }
  }

  private function removeNode(LRUNode<T> $node): void {
    if ($node->prev !== null) {
      $node->prev->next = $node->next;
    } else {
      $this->head = $node->next;
    }

    if ($node->next !== null) {
      $node->next->prev = $node->prev;
    } else {
      $this->tail = $node->prev;
    }
  }

  private function moveToHead(LRUNode<T> $node): void {
    if ($this->head === $node) {
      return;
    }
    $this->removeNode($node);
    $this->addToHead($node);
  }

  private function evictOldest(): void {
    if ($this->tail !== null) {
      $oldest = $this->tail;
      $this->removeNode($oldest);
      unset($this->lookup[$oldest->key]);
    }
  }
}
