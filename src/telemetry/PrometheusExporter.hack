namespace Axon\Telemetry;

/**
 * PrometheusExporter formats collected metrics into OpenMetrics / Prometheus scrape format.
 */
final class PrometheusExporter {
  private MetricsCollector $collector;

  public function __construct(MetricsCollector $collector) {
    $this->collector = $collector;
  }

  public function export(): string {
    $out = '';

    // Export Counters
    foreach ($this->collector->getAllCounters() as $name => $val) {
      $metricName = 'axon_' . $name;
      $out .= \sprintf("# TYPE %s counter\n", $metricName);
      $out .= \sprintf("%s %d\n", $metricName, $val);
    }

    // Export Gauges
    foreach ($this->collector->getAllGauges() as $name => $val) {
      $metricName = 'axon_' . $name;
      $out .= \sprintf("# TYPE %s gauge\n", $metricName);
      $out .= \sprintf("%s %f\n", $metricName, $val);
    }

    // Export Histograms
    foreach ($this->collector->getAllHistograms() as $name => $hist) {
      $metricName = 'axon_' . $name;
      $out .= \sprintf("# TYPE %s histogram\n", $metricName);

      $cumulative = 0;
      $bounds = $hist->getBucketBounds();
      $counts = $hist->getBucketCounts();

      for ($i = 0; $i < \count($bounds); $i++) {
        $cumulative += $counts[$i];
        $out .= \sprintf('%s_bucket{le="%f"} %d' . "\n", $metricName, $bounds[$i], $cumulative);
      }
      $cumulative += $counts[\count($bounds)];
      $out .= \sprintf('%s_bucket{le="+Inf"} %d' . "\n", $metricName, $cumulative);
      $out .= \sprintf("%s_sum %f\n", $metricName, $hist->getSum());
      $out .= \sprintf("%s_count %d\n", $metricName, $hist->getCount());
    }

    return $out;
  }
}
