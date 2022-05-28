namespace Axon\Tests\Unit;

use Axon\ReBAC\ExpandEngine;
use Axon\ReBAC\Subject;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\NamespaceConfig;
use Axon\ReBAC\RelationRule;
use Axon\ReBAC\ThisRewrite;

final class TestReBACExpand {
  public static function run(): void {
    \printf("Running TestReBACExpand...\n");

    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();

    $ns = new NamespaceConfig('project');
    $ns->addRule(new RelationRule('contributor', new ThisRewrite()));
    $policies->registerNamespace($ns);

    $store->insert(new RelationTuple('project', 'prj-1', 'contributor', new Subject('user', 'alice')));
    $store->insert(new RelationTuple('project', 'prj-1', 'contributor', new Subject('user', 'bob')));

    $expander = new ExpandEngine($policies, $store);
    $tree = $expander->expand('project', 'prj-1', 'contributor');

    if (\count($tree->getChildren()) !== 2) {
      throw new \RuntimeException(\sprintf("Expected 2 expanded children, got %d", \count($tree->getChildren())));
    }

    \printf("TestReBACExpand passed.\n");
  }
}
