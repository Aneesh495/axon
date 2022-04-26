namespace Axon\DataLoader;

/**
 * CacheMap provides high-speed in-memory memoization for request-scoped DataLoader instances.
 */
final class CacheMap<TVal> {
  private dict<string, TVal> $entries;

  public function __construct() {
    $this->entries = dict[];
  }

  public function get(string $key): ?TVal {
    return \array_key_exists($key, $this->entries) ? $this->entries[$key] : null;
  }

  public function has(string $key): bool {
    return \array_key_exists($key, $this->entries);
  }

  public function set(string $key, TVal $value): void {
    $this->entries[$key] = $value;
  }

  public function delete(string $key): void {
    if (\array_key_exists($key, $this->entries)) {
      unset($this->entries[$key]);
    }
  }

  public function clear(): void {
    $this->entries = dict[];
  }

  public function count(): int {
    return \count($this->entries);
  }

  public function keys(): vec<string> {
    return vec(\array_keys($this->entries));
  }
}
