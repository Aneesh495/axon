namespace Axon\Tests\Unit;

use Axon\Core\HLC;
use Axon\Core\HLCClock;

final class TestHLC {
  public static function run(): void {
    \printf("Running TestHLC...\n");

    $clock = new HLCClock(5000); // 5 sec max drift

    $t1 = $clock->now(1000);
    if ($t1->getPhysical() !== 1000 || $t1->getLogical() !== 0) {
      throw new \RuntimeException("Initial HLC should have physical=1000, logical=0");
    }

    // Same millisecond generates logical increment
    $t2 = $clock->now(1000);
    if ($t2->getPhysical() !== 1000 || $t2->getLogical() !== 1) {
      throw new \RuntimeException("Same millisecond should increment logical counter");
    }

    if ($t1->compare($t2) >= 0) {
      throw new \RuntimeException("Causal ordering failed: t1 should be less than t2");
    }

    // Remote clock update with higher physical time
    $remote = new HLC(2000, 5);
    $updRes = $clock->update($remote, 1500);
    if ($updRes->isErr()) {
      throw new \RuntimeException("Clock update failed: " . $updRes->unwrapErr());
    }
    $t3 = $updRes->unwrap();
    if ($t3->getPhysical() !== 2000 || $t3->getLogical() !== 6) {
      throw new \RuntimeException("Update should advance to max physical and increment logical");
    }

    // Excessive drift rejection
    $driftRemote = new HLC(100000, 0);
    $driftRes = $clock->update($driftRemote, 1500);
    if ($driftRes->isOk()) {
      throw new \RuntimeException("Excessive clock drift should be rejected");
    }

    \printf("TestHLC passed.\n");
  }
}
