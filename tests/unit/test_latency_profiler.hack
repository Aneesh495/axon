namespace Axon\Tests\Unit;

use Axon\Analytics\LatencyProfiler;

final class TestLatencyProfiler {
  public static function run(): void {
    \printf("Running TestLatencyProfiler...\n");

    $profiler = new LatencyProfiler();

    for ($i = 1; $i <= 100; $i++) {
      $profiler->record((float)$i); // 1.0 to 100.0 microseconds
    }

    if ($profiler->getSampleCount() !== 100) {
      throw new \RuntimeException("Sample count should be 100");
    }

    $p50 = $profiler->getP50();
    $p90 = $profiler->getP90();
    $p99 = $profiler->getP99();

    if ($p50 < 49.0 || $p50 > 51.0) {
      throw new \RuntimeException(\sprintf("p50 expected ~50.0, got %f", $p50));
    }
    if ($p90 < 89.0 || $p90 > 91.0) {
      throw new \RuntimeException(\sprintf("p90 expected ~90.0, got %f", $p90));
    }
    if ($p99 < 98.0 || $p99 > 100.0) {
      throw new \RuntimeException(\sprintf("p99 expected ~99.0, got %f", $p99));
    }

    \printf("TestLatencyProfiler passed.\n");
  }
}
