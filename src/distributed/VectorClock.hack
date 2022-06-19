namespace Axon\Distributed;

/**
 * Ordering relationship between two vector clocks.
 */
enum VectorOrdering: string {
  EQUAL = 'EQUAL';
  BEFORE = 'BEFORE';
  AFTER = 'AFTER';
  CONCURRENT = 'CONCURRENT';
}

/**
 * VectorClock tracks causal event histories across distributed graph partitions.
 */
final class VectorClock implements \JsonSerializable {
  private dict<string, int> $clock;

  public function __construct(dict<string, int> $clock = dict[]) {
    $this->clock = $clock;
  }

  public function increment(string $nodeId): void {
    if (!\array_key_exists($nodeId, $this->clock)) {
      $this->clock[$nodeId] = 0;
    }
    $this->clock[$nodeId]++;
  }

  public function get(string $nodeId): int {
    return \array_key_exists($nodeId, $this->clock) ? $this->clock[$nodeId] : 0;
  }

  public function merge(VectorClock $other): VectorClock {
    $merged = $this->clock;
    foreach ($other->getClock() as $nodeId => $v) {
      if (!\array_key_exists($nodeId, $merged) || $v > $merged[$nodeId]) {
        $merged[$nodeId] = $v;
      }
    }
    return new VectorClock($merged);
  }

  public function compare(VectorClock $other): VectorOrdering {
    $allKeys = keyset[];
    foreach ($this->clock as $k => $_) {
      $allKeys[] = $k;
    }
    foreach ($other->getClock() as $k => $_) {
      $allKeys[] = $k;
    }

    $hasGreater = false;
    $hasLesser = false;

    foreach ($allKeys as $k) {
      $v1 = $this->get($k);
      $v2 = $other->get($k);

      if ($v1 > $v2) {
        $hasGreater = true;
      } else if ($v1 < $v2) {
        $hasLesser = true;
      }
    }

    if ($hasGreater && $hasLesser) {
      return VectorOrdering::CONCURRENT;
    }
    if ($hasGreater) {
      return VectorOrdering::AFTER;
    }
    if ($hasLesser) {
      return VectorOrdering::BEFORE;
    }
    return VectorOrdering::EQUAL;
  }

  public function getClock(): dict<string, int> {
    return $this->clock;
  }

  public function jsonSerialize(): dict<string, int> {
    return $this->clock;
  }
}
