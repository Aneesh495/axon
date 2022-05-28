namespace Axon\Tests\Unit;

use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\ListObjectsEngine;
use Axon\ReBAC\Subject;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\NamespaceConfig;
use Axon\ReBAC\RelationRule;
use Axon\ReBAC\ThisRewrite;

final class TestReBACList {
  public static function run(): void {
    \printf("Running TestReBACList...\n");

    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();

    $ns = new NamespaceConfig('file');
    $ns->addRule(new RelationRule('reader', new ThisRewrite()));
    $policies->registerNamespace($ns);

    $alice = new Subject('user', 'alice');
    $store->insert(new RelationTuple('file', 'f-1', 'reader', $alice));
    $store->insert(new RelationTuple('file', 'f-3', 'reader', $alice));

    $checker = new CheckEngine($policies, $store);
    $lister = new ListObjectsEngine($checker, $store);

    $candidates = vec['f-1', 'f-2', 'f-3', 'f-4'];
    $allowed = $lister->listObjects('file', 'reader', $alice, $candidates);

    if (\count($allowed) !== 2 || $allowed[0] !== 'f-1' || $allowed[1] !== 'f-3') {
      throw new \RuntimeException("ListObjects failed to return expected file IDs");
    }

    \printf("TestReBACList passed.\n");
  }
}
