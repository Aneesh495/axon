namespace Axon\Telemetry;

/**
 * Metric types supported by Axon.
 */
enum MetricType: string {
  COUNTER = 'COUNTER';
  GAUGE = 'GAUGE';
  HISTOGRAM = 'HISTOGRAM';
}

/**
 * Histogram metric maintaining bucket distributions and quantiles.
 */
final class Histogram {
  private string $name;
  private vec<float> $bucketBounds;
  private vec<int> $bucketCounts;
  private int $count;
  private float $sum;

  public function __construct(string $name, vec<float> $bucketBounds) {
    $this->name = $name;
    $this->bucketBounds = $bucketBounds;
    $this->bucketCounts = vec[];
    for ($i = 0; $i <= \count($bucketBounds); $i++) {
      $this->bucketCounts[] = 0;
    }
    $this->count = 0;
    $this->sum = 0.0;
  }

  public function observe(float $val): void {
    $this->count++;
    $this->sum += $val;

    $placed = false;
    for ($i = 0; $i < \count($this->bucketBounds); $i++) {
      if ($val <= $this->bucketBounds[$i]) {
        $this->bucketCounts[$i]++;
        $placed = true;
        break;
      }
    }
    if (!$placed) {
      $this->bucketCounts[\count($this->bucketBounds)]++;
    }
  }

  public function getCount(): int {
    return $this->count;
  }

  public function getSum(): float {
    return $this->sum;
  }

  public function getBucketBounds(): vec<float> {
    return $this->bucketBounds;
  }

  public function getBucketCounts(): vec<int> {
    return $this->bucketCounts;
  }
}

/**
 * MetricsCollector maintains counters, gauges, and latency histograms.
 */
final class MetricsCollector {
  private dict<string, int> $counters;
  private dict<string, float> $gauges;
  private dict<string, Histogram> $histograms;

  public function __construct() {
    $this->counters = dict[];
    $this->gauges = dict[];
    $this->histograms = dict[];
  }

  public function increment(string $name, int $delta = 1): void {
    if (!\array_key_exists($name, $this->counters)) {
      $this->counters[$name] = 0;
    }
    $this->counters[$name] += $delta;
  }

  public function getCounter(string $name): int {
    return \array_key_exists($name, $this->counters) ? $this->counters[$name] : 0;
  }

  public function setGauge(string $name, float $value): void {
    $this->gauges[$name] = $value;
  }

  public function getGauge(string $name): float {
    return \array_key_exists($name, $this->gauges) ? $this->gauges[$name] : 0.0;
  }

  public function observeHistogram(string $name, float $value, ?vec<float> $bounds = null): void {
    if (!\array_key_exists($name, $this->histograms)) {
      $defaultBounds = $bounds ?? vec[1.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0];
      $this->histograms[$name] = new Histogram($name, $defaultBounds);
    }
    $this->histograms[$name]->observe($value);
  }

  public function getHistogram(string $name): ?Histogram {
    return \array_key_exists($name, $this->histograms) ? $this->histograms[$name] : null;
  }

  public function getAllCounters(): dict<string, int> {
    return $this->counters;
  }

  public function getAllGauges(): dict<string, float> {
    return $this->gauges;
  }

  public function getAllHistograms(): dict<string, Histogram> {
    return $this->histograms;
  }
}
