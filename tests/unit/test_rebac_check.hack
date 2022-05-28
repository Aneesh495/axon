namespace Axon\Tests\Unit;

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
use Axon\ReBAC\ComputedUsersetRewrite;
use Axon\ReBAC\TupleToUsersetRewrite;

final class TestReBACCheck {
  public static function run(): void {
    \printf("Running TestReBACCheck...\n");

    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();

    // 1. Setup workspace namespace:
    // owner: this
    // member: this | owner
    $wsNs = new NamespaceConfig('workspace');
    $wsNs->addRule(new RelationRule('owner', new ThisRewrite()));
    $wsNs->addRule(new RelationRule('member', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('owner'),
    ])));
    $policies->registerNamespace($wsNs);

    // 2. Setup document namespace:
    // owner: this
    // viewer: this | owner | parent_workspace.member
    $docNs = new NamespaceConfig('document');
    $docNs->addRule(new RelationRule('owner', new ThisRewrite()));
    $docNs->addRule(new RelationRule('viewer', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('owner'),
      new TupleToUsersetRewrite('parent_workspace', 'member'),
    ])));
    $policies->registerNamespace($docNs);

    $checker = new CheckEngine($policies, $store);

    $alice = new Subject('user', 'alice');
    $bob = new Subject('user', 'bob');
    $charlie = new Subject('user', 'charlie');

    // Alice owns workspace-1
    $store->insert(new RelationTuple('workspace', 'ws-1', 'owner', $alice));
    // Bob is member of workspace-1
    $store->insert(new RelationTuple('workspace', 'ws-1', 'member', $bob));
    // doc-1 belongs to workspace-1
    $store->insert(new RelationTuple('document', 'doc-1', 'parent_workspace', new Subject('workspace', 'ws-1')));

    // Alice should be viewer on doc-1 (via owner -> member of ws-1 -> parent_workspace)
    $reqAlice = new CheckRequest('document', 'doc-1', 'viewer', $alice);
    $respAlice = $checker->check($reqAlice);
    if (!$respAlice->isAllowed()) {
      throw new \RuntimeException("Alice should be allowed viewer on doc-1 via inherited workspace ownership");
    }

    // Bob should be viewer on doc-1 (via member of ws-1)
    $reqBob = new CheckRequest('document', 'doc-1', 'viewer', $bob);
    $respBob = $checker->check($reqBob);
    if (!$respBob->isAllowed()) {
      throw new \RuntimeException("Bob should be allowed viewer on doc-1 via workspace membership");
    }

    // Charlie has no relations and should be denied
    $reqCharlie = new CheckRequest('document', 'doc-1', 'viewer', $charlie);
    $respCharlie = $checker->check($reqCharlie);
    if ($respCharlie->isAllowed()) {
      throw new \RuntimeException("Charlie should be denied viewer on doc-1");
    }

    \printf("TestReBACCheck passed.\n");
  }
}
