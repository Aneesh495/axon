namespace Axon\Tests\Unit;

use Axon\Analytics\GraphMetrics;

final class TestGraphMetrics {
  public static function run(): void {
    \printf("Running TestGraphMetrics...\n");

    $metrics = new GraphMetrics();

    // Build directed graph: A -> B, A -> C, B -> C
    $metrics->addEdge('NodeA', 'NodeB');
    $metrics->addEdge('NodeA', 'NodeC');
    $metrics->addEdge('NodeB', 'NodeC');

    if ($metrics->getNodeCount() !== 3) {
      throw new \RuntimeException("Node count should be 3");
    }
    if ($metrics->getEdgeCount() !== 3) {
      throw new \RuntimeException("Edge count should be 3");
    }

    if ($metrics->getOutDegree('NodeA') !== 2) {
      throw new \RuntimeException("NodeA out-degree should be 2");
    }
    if ($metrics->getInDegree('NodeC') !== 2) {
      throw new \RuntimeException("NodeC in-degree should be 2");
    }

    \printf("TestGraphMetrics passed.\n");
  }
}
