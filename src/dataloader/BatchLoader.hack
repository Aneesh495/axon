namespace Axon\DataLoader;

use Axon\Core\AsyncDeferred;

/**
 * BatchLoader provides a request-scoped batching and caching layer
 * to eliminate N+1 queries across asynchronous graph resolutions.
 */
class BatchLoader<TKey, TValue> {
  private (function(vec<TKey>): dict<string, TValue>) $batchFn;
  private CacheMap<TValue> $cache;
  private vec<TKey> $queue;
  private dict<string, vec<AsyncDeferred<TValue>>> $pendingDeferreds;
  private int $maxBatchSize;

  public function __construct(
    (function(vec<TKey>): dict<string, TValue>) $batchFn,
    int $maxBatchSize = 1024
  ) {
    $this->batchFn = $batchFn;
    $this->cache = new CacheMap<TValue>();
    $this->queue = vec[];
    $this->pendingDeferreds = dict[];
    $this->maxBatchSize = $maxBatchSize;
  }

  /**
   * Loads a key, returning an AsyncDeferred that resolves once the batch executes.
   */
  public function load(TKey $key, string $keyStr): AsyncDeferred<TValue> {
    // 1. Check request cache
    if ($this->cache->has($keyStr)) {
      $val = $this->cache->get($keyStr) as nonnull;
      $deferred = new AsyncDeferred<TValue>();
      $deferred->resolve($val);
      return $deferred;
    }

    // 2. Enqueue for batch dispatch
    $deferred = new AsyncDeferred<TValue>();

    if (!\array_key_exists($keyStr, $this->pendingDeferreds)) {
      $this->pendingDeferreds[$keyStr] = vec[];
      $this->queue[] = $key;
    }

    $list = $this->pendingDeferreds[$keyStr];
    $list[] = $deferred;
    $this->pendingDeferreds[$keyStr] = $list;

    if (\count($this->queue) >= $this->maxBatchSize) {
      $this->dispatch();
    }

    return $deferred;
  }

  /**
   * Immediately primes the cache with an already known key-value pair.
   */
  public function prime(string $keyStr, TValue $value): void {
    if (!$this->cache->has($keyStr)) {
      $this->cache->set($keyStr, $value);
    }
  }

  /**
   * Clears a specific key from the cache.
   */
  public function clear(string $keyStr): void {
    $this->cache->delete($keyStr);
  }

  /**
   * Clears the entire cache.
   */
  public function clearAll(): void {
    $this->cache->clear();
  }

  /**
   * Dispatches all enqueued keys through the batch function.
   */
  public function dispatch(): void {
    if (\count($this->queue) === 0) {
      return;
    }

    $keys = $this->queue;
    $deferreds = $this->pendingDeferreds;

    $this->queue = vec[];
    $this->pendingDeferreds = dict[];

    try {
      $results = ($this->batchFn)($keys);

      foreach ($deferreds as $keyStr => $list) {
        if (\array_key_exists($keyStr, $results)) {
          $val = $results[$keyStr];
          $this->cache->set($keyStr, $val);
          foreach ($list as $def) {
            $def->resolve($val);
          }
        } else {
          $err = new \RuntimeException('Key not found in batch result: ' . $keyStr);
          foreach ($list as $def) {
            $def->reject($err);
          }
        }
      }
    } catch (\Throwable $e) {
      foreach ($deferreds as $keyStr => $list) {
        foreach ($list as $def) {
          $def->reject($e);
        }
      }
    }
  }
}
