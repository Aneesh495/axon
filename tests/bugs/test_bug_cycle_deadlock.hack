namespace Axon\Tests\Bugs;

use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;
use Axon\ReBAC\Subject;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\NamespaceConfig;
use Axon\ReBAC\RelationRule;
use Axon\ReBAC\ComputedUsersetRewrite;

/**
 * Regression Test: Bug #104
 * Description: Mutual recursive group membership caused infinite recursion and stack overflow.
 * Resolution: Added visited state memoization set (object, relation, subject) in CheckEngine.
 */
final class TestBugCycleDeadlock {
  public static function run(): void {
    \printf("Running TestBugCycleDeadlock...\n");

    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();

    $groupNs = new NamespaceConfig('group');
    // member relation evaluates computed userset 'member' transitively
    $groupNs->addRule(new RelationRule('member', new ComputedUsersetRewrite('member')));
    $policies->registerNamespace($groupNs);

    $alice = new Subject('user', 'alice');

    // Group A is member of Group B; Group B is member of Group A
    $store->insert(new RelationTuple('group', 'grp-a', 'member', new Subject('group', 'grp-b', 'member')));
    $store->insert(new RelationTuple('group', 'grp-b', 'member', new Subject('group', 'grp-a', 'member')));

    $checker = new CheckEngine($policies, $store, 16);
    $req = new CheckRequest('group', 'grp-a', 'member', $alice);

    $resp = $checker->check($req);

    // Should cleanly terminate and return false without throwing stack overflow
    if ($resp->isAllowed()) {
      throw new \RuntimeException("Cyclic relation check without base case should not evaluate to true");
    }

    \printf("TestBugCycleDeadlock passed.\n");
  }
}
