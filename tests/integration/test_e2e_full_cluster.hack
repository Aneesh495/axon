namespace Axon\Tests\Integration;

use Axon\Distributed\ConsistentHashRing;
use Axon\Distributed\VectorClock;
use Axon\Distributed\VectorOrdering;
use Axon\Distributed\PeerNode;
use Axon\Distributed\NodeState;
use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;
use Axon\ReBAC\Subject;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\NamespaceConfig;
use Axon\ReBAC\RelationRule;
use Axon\ReBAC\ThisRewrite;

final class TestE2EFullCluster {
  public static function run(): void {
    \printf("Running TestE2EFullCluster...\n");

    // 1. Setup 3 cluster peer nodes
    $node1 = new PeerNode('node-1', '10.0.0.1', 9080, NodeState::LEADER);
    $node2 = new PeerNode('node-2', '10.0.0.2', 9080, NodeState::FOLLOWER);
    $node3 = new PeerNode('node-3', '10.0.0.3', 9080, NodeState::FOLLOWER);

    if (!$node1->isAlive() || !$node2->isAlive() || !$node3->isAlive()) {
      throw new \RuntimeException("Cluster nodes should report alive status");
    }

    // 2. Consistent hashing shard assignment
    $ring = new ConsistentHashRing(50);
    $ring->addNode('node-1');
    $ring->addNode('node-2');
    $ring->addNode('node-3');

    $assignedShard = $ring->getNode('doc-corpus-777');
    if ($assignedShard === null) {
      throw new \RuntimeException("Failed to route key along consistent hash ring");
    }

    // 3. Vector clock replication between nodes
    $vc1 = new VectorClock();
    $vc1->increment('node-1'); // node-1: 1

    $vc2 = new VectorClock();
    $vc2->increment('node-1');
    $vc2->increment('node-2'); // node-1: 1, node-2: 1

    if ($vc1->compare($vc2) !== VectorOrdering::BEFORE) {
      throw new \RuntimeException("Causal vector clock before check failed");
    }

    // 4. Distributed ReBAC check execution
    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();
    $ns = new NamespaceConfig('cluster_resource');
    $ns->addRule(new RelationRule('admin', new ThisRewrite()));
    $policies->registerNamespace($ns);

    $alice = new Subject('user', 'alice');
    $store->insert(new RelationTuple('cluster_resource', 'res-1', 'admin', $alice));

    $checker = new CheckEngine($policies, $store);
    $req = new CheckRequest('cluster_resource', 'res-1', 'admin', $alice);

    if (!$checker->check($req)->isAllowed()) {
      throw new \RuntimeException("Cluster admin permission check failed");
    }

    \printf("TestE2EFullCluster passed.\n");
  }
}
