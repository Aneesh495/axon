namespace Axon\Tests\Unit;

use Axon\Cache\SlidingWindowCache;

final class TestSlidingWindowCache {
  public static function run(): void {
    \printf("Running TestSlidingWindowCache...\n");

    $sw = new SlidingWindowCache(5000); // 5 sec window

    // Record accesses at t=1000, t=2000, t=3000
    $sw->recordAccess('client-1', 1000);
    $sw->recordAccess('client-1', 2000);
    $count = $sw->recordAccess('client-1', 3000);

    if ($count !== 3) {
      throw new \RuntimeException(\sprintf("Expected rate count 3, got %d", $count));
    }

    // Access at t=7000 (t=1000 has expired since 7000 - 5000 = 2000)
    $newCount = $sw->recordAccess('client-1', 7000);
    if ($newCount !== 3) { // 2000, 3000, 7000
      throw new \RuntimeException(\sprintf("Expected 3 valid accesses after sliding window shift, got %d", $newCount));
    }

    \printf("TestSlidingWindowCache passed.\n");
  }
}
