namespace Axon\Tests\Unit;

use Axon\DataLoader\BatchLoader;

final class TestDataLoader {
  public static function run(): void {
    \printf("Running TestDataLoader...\n");

    $batchFetchCount = 0;
    $batchFn = (vec<string> $keys) ==> {
      $batchFetchCount++;
      $results = dict[];
      foreach ($keys as $k) {
        $results[$k] = 'val_' . $k;
      }
      return $results;
    };

    $loader = new BatchLoader<string, string>($batchFn);

    // Enqueue two deferred loads
    $d1 = $loader->load('k1', 'k1');
    $d2 = $loader->load('k2', 'k2');

    // Both should still be pending before dispatch
    if (!$d1->isPending() || !$d2->isPending()) {
      throw new \RuntimeException("Deferreds should be pending before dispatch");
    }

    $loader->dispatch();

    if (!$d1->isResolved() || !$d2->isResolved()) {
      throw new \RuntimeException("Deferreds should be resolved after dispatch");
    }

    if ($d1->awaitResult() !== 'val_k1' || $d2->awaitResult() !== 'val_k2') {
      throw new \RuntimeException("BatchLoader returned unexpected values");
    }

    // Subsequent load for 'k1' should hit request cache without another batch fetch
    $d3 = $loader->load('k1', 'k1');
    if (!$d3->isResolved() || $d3->awaitResult() !== 'val_k1') {
      throw new \RuntimeException("Cache hit load should resolve immediately");
    }

    \printf("TestDataLoader passed.\n");
  }
}
