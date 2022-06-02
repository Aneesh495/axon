namespace Axon\Tests\Bugs;

use Axon\DataLoader\BatchLoader;

/**
 * Regression Test: Bug #212
 * Description: Rapid concurrent key additions to BatchLoader during active dispatch
 * caused pending deferred list starvation.
 * Resolution: Atomic queue extraction and state swap prior to batch callback invocation.
 */
final class TestBugBatchCoalesce {
  public static function run(): void {
    \printf("Running TestBugBatchCoalesce...\n");

    $callCount = 0;
    $batchFn = (vec<string> $keys) ==> {
      $callCount++;
      $map = dict[];
      foreach ($keys as $k) {
        $map[$k] = 'val_' . $k;
      }
      return $map;
    };

    $loader = new BatchLoader<string, string>($batchFn, 10);

    $d1 = $loader->load('k1', 'k1');
    $d2 = $loader->load('k2', 'k2');
    $loader->dispatch();

    if (!$d1->isResolved() || !$d2->isResolved()) {
      throw new \RuntimeException("First batch deferreds failed to resolve");
    }

    $d3 = $loader->load('k3', 'k3');
    $loader->dispatch();

    if (!$d3->isResolved() || $d3->awaitResult() !== 'val_k3') {
      throw new \RuntimeException("Subsequent batch load failed to resolve");
    }

    \printf("TestBugBatchCoalesce passed.\n");
  }
}
