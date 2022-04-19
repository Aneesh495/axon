namespace Axon\Core;

/**
 * TaskState represents the execution status of an asynchronous batch task.
 */
enum TaskState: string {
  PENDING = 'PENDING';
  RESOLVED = 'RESOLVED';
  REJECTED = 'REJECTED';
}

/**
 * AsyncDeferred represents a future completion token for an async batch operation.
 */
final class AsyncDeferred<T> {
  private TaskState $state;
  private ?T $value;
  private ?\Throwable $exception;

  public function __construct() {
    $this->state = TaskState::PENDING;
    $this->value = null;
    $this->exception = null;
  }

  public function resolve(T $val): void {
    if ($this->state !== TaskState::PENDING) {
      return;
    }
    $this->state = TaskState::RESOLVED;
    $this->value = $val;
  }

  public function reject(\Throwable $e): void {
    if ($this->state !== TaskState::PENDING) {
      return;
    }
    $this->state = TaskState::REJECTED;
    $this->exception = $e;
  }

  public function isPending(): bool {
    return $this->state === TaskState::PENDING;
  }

  public function isResolved(): bool {
    return $this->state === TaskState::RESOLVED;
  }

  public function isRejected(): bool {
    return $this->state === TaskState::REJECTED;
  }

  public function awaitResult(): T {
    if ($this->state === TaskState::RESOLVED) {
      return $this->value as nonnull;
    }
    if ($this->state === TaskState::REJECTED) {
      throw $this->exception as nonnull;
    }
    throw new \RuntimeException('Attempted to await pending deferred task');
  }
}

/**
 * AsyncBatcher coalesces individual key requests into consolidated batch dispatches,
 * eliminating the classic N+1 query problem across asynchronous execution trees.
 */
final class AsyncBatcher<TKey, TValue> {
  private (function(vec<TKey>): dict<string, TValue>) $batchFn;
  private int $maxBatchSize;
  private vec<TKey> $pendingKeys;
  private dict<string, vec<AsyncDeferred<TValue>>> $pendingDeferreds;

  public function __construct(
    (function(vec<TKey>): dict<string, TValue>) $batchFn,
    int $maxBatchSize = 1000
  ) {
    $this->batchFn = $batchFn;
    $this->maxBatchSize = $maxBatchSize;
    $this->pendingKeys = vec[];
    $this->pendingDeferreds = dict[];
  }

  /**
   * Enqueues a key for deferred resolution in the next batch dispatch.
   */
  public function load(TKey $key, string $keyStr): AsyncDeferred<TValue> {
    $deferred = new AsyncDeferred<TValue>();

    if (!\array_key_exists($keyStr, $this->pendingDeferreds)) {
      $this->pendingDeferreds[$keyStr] = vec[];
      $this->pendingKeys[] = $key;
    }

    $list = $this->pendingDeferreds[$keyStr];
    $list[] = $deferred;
    $this->pendingDeferreds[$keyStr] = $list;

    if (\count($this->pendingKeys) >= $this->maxBatchSize) {
      $this->dispatch();
    }

    return $deferred;
  }

  /**
   * Dispatches all currently accumulated keys in a single batch call.
   */
  public function dispatch(): void {
    if (\count($this->pendingKeys) === 0) {
      return;
    }

    $keysToFetch = $this->pendingKeys;
    $deferredsToResolve = $this->pendingDeferreds;

    // Reset pending buffers before invoking batch execution
    $this->pendingKeys = vec[];
    $this->pendingDeferreds = dict[];

    try {
      $results = ($this->batchFn)($keysToFetch);
      foreach ($deferredsToResolve as $keyStr => $deferredList) {
        if (\array_key_exists($keyStr, $results)) {
          $val = $results[$keyStr];
          foreach ($deferredList as $def) {
            $def->resolve($val);
          }
        } else {
          $err = new \RuntimeException('Batchloader returned no value for key: ' . $keyStr);
          foreach ($deferredList as $def) {
            $def->reject($err);
          }
        }
      }
    } catch (\Throwable $e) {
      foreach ($deferredsToResolve as $keyStr => $deferredList) {
        foreach ($deferredList as $def) {
          $def->reject($e);
        }
      }
    }
  }

  public function pendingCount(): int {
    return \count($this->pendingKeys);
  }
}
