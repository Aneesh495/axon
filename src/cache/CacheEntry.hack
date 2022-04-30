namespace Axon\Cache;

/**
 * CacheEntry encapsulates a cached item along with time-to-live and telemetry metadata.
 */
final class CacheEntry<T> {
  private string $key;
  private T $value;
  private int $createdAtMs;
  private int $ttlSeconds;
  private int $accessCount;
  private int $lastAccessedMs;
  private int $version;

  public function __construct(
    string $key,
    T $value,
    int $ttlSeconds = 0,
    int $version = 1,
    int $nowMs = 0
  ) {
    $currentTime = $nowMs > 0 ? $nowMs : (int)(\microtime(true) * 1000.0);
    $this->key = $key;
    $this->value = $value;
    $this->createdAtMs = $currentTime;
    $this->ttlSeconds = $ttlSeconds;
    $this->accessCount = 0;
    $this->lastAccessedMs = $currentTime;
    $this->version = $version;
  }

  public function getKey(): string {
    return $this->key;
  }

  public function getValue(): T {
    return $this->value;
  }

  public function getCreatedAtMs(): int {
    return $this->createdAtMs;
  }

  public function getTtlSeconds(): int {
    return $this->ttlSeconds;
  }

  public function getAccessCount(): int {
    return $this->accessCount;
  }

  public function getVersion(): int {
    return $this->version;
  }

  public function recordAccess(int $nowMs = 0): void {
    $this->accessCount++;
    $this->lastAccessedMs = $nowMs > 0 ? $nowMs : (int)(\microtime(true) * 1000.0);
  }

  public function isExpired(int $nowMs = 0): bool {
    if ($this->ttlSeconds <= 0) {
      return false;
    }
    $currentTime = $nowMs > 0 ? $nowMs : (int)(\microtime(true) * 1000.0);
    $expirationMs = $this->createdAtMs + ($this->ttlSeconds * 1000);
    return $currentTime >= $expirationMs;
  }
}
