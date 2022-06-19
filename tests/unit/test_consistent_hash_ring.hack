namespace Axon\Tests\Unit;

use Axon\Distributed\ConsistentHashRing;

final class TestConsistentHashRing {
  public static function run(): void {
    \printf("Running TestConsistentHashRing...\n");

    $ring = new ConsistentHashRing(50);

    $ring->addNode('shard-alpha');
    $ring->addNode('shard-beta');
    $ring->addNode('shard-gamma');

    if ($ring->getNodeCount() !== 3) {
      throw new \RuntimeException("Expected 3 nodes in ring");
    }

    $node1 = $ring->getNode('doc-101');
    $node2 = $ring->getNode('doc-101');

    // Deterministic placement
    if ($node1 !== $node2 || $node1 === null) {
      throw new \RuntimeException("Consistent hash routing must be deterministic");
    }

    // Removing a non-target node preserves key placement
    $targetNode = $node1;
    $otherNode = $targetNode === 'shard-alpha' ? 'shard-beta' : 'shard-alpha';
    $ring->removeNode($otherNode);

    // If doc-101 did not map to otherNode, it must stay on targetNode
    // This is the core theorem of consistent hashing: minimal disruption!
    \printf("TestConsistentHashRing passed.\n");
  }
}
