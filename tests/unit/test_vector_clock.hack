namespace Axon\Tests\Unit;

use Axon\Distributed\VectorClock;
use Axon\Distributed\VectorOrdering;

final class TestVectorClock {
  public static function run(): void {
    \printf("Running TestVectorClock...\n");

    $vc1 = new VectorClock();
    $vc1->increment('node-A'); // A:1

    $vc2 = new VectorClock();
    $vc2->increment('node-A'); // A:1
    $vc2->increment('node-B'); // B:1

    // vc1 is causally strictly before vc2
    if ($vc1->compare($vc2) !== VectorOrdering::BEFORE) {
      throw new \RuntimeException("vc1 should be BEFORE vc2");
    }
    if ($vc2->compare($vc1) !== VectorOrdering::AFTER) {
      throw new \RuntimeException("vc2 should be AFTER vc1");
    }

    // Concurrent branch: vc3 has incremented node-C
    $vc3 = new VectorClock();
    $vc3->increment('node-C');

    if ($vc2->compare($vc3) !== VectorOrdering::CONCURRENT) {
      throw new \RuntimeException("vc2 and vc3 should be CONCURRENT conflict");
    }

    // Merge vc2 and vc3
    $merged = $vc2->merge($vc3);
    if ($merged->get('node-A') !== 1 || $merged->get('node-B') !== 1 || $merged->get('node-C') !== 1) {
      throw new \RuntimeException("Merged vector clock values mismatch");
    }

    \printf("TestVectorClock passed.\n");
  }
}
