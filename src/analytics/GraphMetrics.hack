namespace Axon\Analytics;

/**
 * GraphMetrics computes structural and topological properties of the object graph.
 */
final class GraphMetrics {
  private dict<string, vec<string>> $adjacency;
  private int $edgeCount;

  public function __construct() {
    $this->adjacency = dict[];
    $this->edgeCount = 0;
  }

  public function addEdge(string $fromNode, string $toNode): void {
    if (!\array_key_exists($fromNode, $this->adjacency)) {
      $this->adjacency[$fromNode] = vec[];
    }
    $list = $this->adjacency[$fromNode];
    $list[] = $toNode;
    $this->adjacency[$fromNode] = $list;
    $this->edgeCount++;

    // Ensure target node is also in adjacency map
    if (!\array_key_exists($toNode, $this->adjacency)) {
      $this->adjacency[$toNode] = vec[];
    }
  }

  public function getNodeCount(): int {
    return \count($this->adjacency);
  }

  public function getEdgeCount(): int {
    return $this->edgeCount;
  }

  public function getOutDegree(string $node): int {
    return \array_key_exists($node, $this->adjacency) ? \count($this->adjacency[$node]) : 0;
  }

  public function getInDegree(string $targetNode): int {
    $count = 0;
    foreach ($this->adjacency as $neighbors) {
      foreach ($neighbors as $n) {
        if ($n === $targetNode) {
          $count++;
        }
      }
    }
    return $count;
  }

  public function getAverageDegree(): float {
    $nodes = $this->getNodeCount();
    if ($nodes === 0) {
      return 0.0;
    }
    return (float)($this->edgeCount * 2) / (float)$nodes;
  }

  public function clear(): void {
    $this->adjacency = dict[];
    $this->edgeCount = 0;
  }
}
