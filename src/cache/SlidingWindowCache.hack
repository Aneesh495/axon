namespace Axon\Cache;

/**
 * SlidingWindowCache provides temporal window rate tracking and burst query dampening.
 */
final class SlidingWindowCache {
  private int $windowMs;
  private dict<string, vec<int>> $accessLog;

  public function __construct(int $windowMs = 60000) {
    $this->windowMs = $windowMs;
    $this->accessLog = dict[];
  }

  public function recordAccess(string $key, int $nowMs = 0): int {
    $current = $nowMs > 0 ? $nowMs : (int)(\microtime(true) * 1000.0);
    $threshold = $current - $this->windowMs;

    if (!\array_key_exists($key, $this->accessLog)) {
      $this->accessLog[$key] = vec[];
    }

    $valid = vec[];
    foreach ($this->accessLog[$key] as $ts) {
      if ($ts > $threshold) {
        $valid[] = $ts;
      }
    }
    $valid[] = $current;
    $this->accessLog[$key] = $valid;

    return \count($valid);
  }

  public function getRate(string $key, int $nowMs = 0): int {
    $current = $nowMs > 0 ? $nowMs : (int)(\microtime(true) * 1000.0);
    $threshold = $current - $this->windowMs;

    if (!\array_key_exists($key, $this->accessLog)) {
      return 0;
    }

    $count = 0;
    foreach ($this->accessLog[$key] as $ts) {
      if ($ts > $threshold) {
        $count++;
      }
    }
    return $count;
  }

  public function clear(): void {
    $this->accessLog = dict[];
  }
}
