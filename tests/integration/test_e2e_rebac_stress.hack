namespace Axon\Tests\Integration;

use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;
use Axon\ReBAC\Subject;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\NamespaceConfig;
use Axon\ReBAC\RelationRule;
use Axon\ReBAC\UnionRewrite;
use Axon\ReBAC\ThisRewrite;
use Axon\ReBAC\TupleToUsersetRewrite;

final class TestE2EReBACStress {
  public static function run(): void {
    \printf("Running TestE2EReBACStress...\n");

    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();

    $folderNs = new NamespaceConfig('folder');
    $folderNs->addRule(new RelationRule('parent', new ThisRewrite()));
    $folderNs->addRule(new RelationRule('viewer', new UnionRewrite(vec[
      new ThisRewrite(),
      new TupleToUsersetRewrite('parent', 'viewer'),
    ])));
    $policies->registerNamespace($folderNs);

    $alice = new Subject('user', 'alice');

    // Build 20-level deep chain: folder_0 -> folder_1 -> ... -> folder_19
    $store->insert(new RelationTuple('folder', 'folder_0', 'viewer', $alice));
    for ($i = 1; $i < 20; $i++) {
      $parentObj = \sprintf('folder_%d', $i - 1);
      $curObj = \sprintf('folder_%d', $i);
      $store->insert(new RelationTuple('folder', $curObj, 'parent', new Subject('folder', $parentObj)));
    }

    $checker = new CheckEngine($policies, $store, 32);

    // Alice should be allowed on folder_19 via 20-level transitive inheritance
    $req = new CheckRequest('folder', 'folder_19', 'viewer', $alice);
    $resp = $checker->check($req);

    if (!$resp->isAllowed()) {
      throw new \RuntimeException("Stress test failed: 20-level transitive reachability denied");
    }

    \printf("TestE2EReBACStress passed (evaluated depth: %d).\n", $resp->getDepth());
  }
}
