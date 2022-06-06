namespace Axon\Tests\Unit;

use Axon\ReBAC\PermissionExplainer;
use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;
use Axon\ReBAC\Subject;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\NamespaceConfig;
use Axon\ReBAC\RelationRule;
use Axon\ReBAC\ThisRewrite;

final class TestPermissionExplainer {
  public static function run(): void {
    \printf("Running TestPermissionExplainer...\n");

    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();

    $ns = new NamespaceConfig('vault');
    $ns->addRule(new RelationRule('custodian', new ThisRewrite()));
    $policies->registerNamespace($ns);

    $alice = new Subject('user', 'alice');
    $store->insert(new RelationTuple('vault', 'v-1', 'custodian', $alice));

    $checker = new CheckEngine($policies, $store);
    $explainer = new PermissionExplainer($checker);

    $req = new CheckRequest('vault', 'v-1', 'custodian', $alice);
    $explanation = $explainer->explain($req);

    if (!$explanation->isPassed()) {
      throw new \RuntimeException("Explanation should reflect passed check");
    }

    if (!\str_contains($explanation->getDescription(), 'HAS permission')) {
      throw new \RuntimeException("Explanation description mismatch");
    }

    \printf("TestPermissionExplainer passed.\n");
  }
}
