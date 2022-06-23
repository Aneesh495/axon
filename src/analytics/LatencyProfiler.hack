namespace Axon\Analytics;

/**
 * LatencyProfiler collects microsecond measurements and computes exact percentiles.
 */
final class LatencyProfiler {
  private vec<float> $samples;
  private int $maxSamples;

  public function __construct(int $maxSamples = 100000) {
    $this->samples = vec[];
    $this->maxSamples = $maxSamples;
  }

  public function record(float $micros): void {
    if (\count($this->samples) >= $this->maxSamples) {
      $this->samples = \array_slice($this->samples, 1000);
    }
    $this->samples[] = $micros;
  }

  public function getPercentile(float $p): float {
    $count = \count($this->samples);
    if ($count === 0) {
      return 0.0;
    }

    $sorted = $this->samples;
    \sort(&$sorted);

    $index = (int)($p * (float)($count - 1));
    $index = \max(0, \min($count - 1, $index));

    return $sorted[$index];
  }

  public function getP50(): float {
    return $this->getPercentile(0.50);
  }

  public function getP90(): float {
    return $this->getPercentile(0.90);
  }

  public function getP99(): float {
    return $this->getPercentile(0.99);
  }

  public function getSampleCount(): int {
    return \count($this->samples);
  }

  public function clear(): void {
    $this->samples = vec[];
  }
}
