namespace Axon\Tests\Unit;

use Axon\Telemetry\MetricsCollector;
use Axon\Telemetry\PrometheusExporter;

final class TestMetrics {
  public static function run(): void {
    \printf("Running TestMetrics...\n");

    $collector = new MetricsCollector();

    $collector->increment('requests_total', 10);
    $collector->setGauge('active_connections', 42.0);
    $collector->observeHistogram('query_latency_ms', 12.5);
    $collector->observeHistogram('query_latency_ms', 45.0);

    if ($collector->getCounter('requests_total') !== 10) {
      throw new \RuntimeException("Counter mismatch");
    }
    if ($collector->getGauge('active_connections') !== 42.0) {
      throw new \RuntimeException("Gauge mismatch");
    }

    $hist = $collector->getHistogram('query_latency_ms');
    if ($hist === null || $hist->getCount() !== 2) {
      throw new \RuntimeException("Histogram observation count mismatch");
    }

    $exporter = new PrometheusExporter($collector);
    $scrapeText = $exporter->export();

    if (!\str_contains($scrapeText, 'axon_requests_total 10')) {
      throw new \RuntimeException("Scrape output missing counter");
    }
    if (!\str_contains($scrapeText, 'axon_active_connections 42')) {
      throw new \RuntimeException("Scrape output missing gauge");
    }

    \printf("TestMetrics passed.\n");
  }
}
