namespace Axon\CLI;

use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;
use Axon\ReBAC\Subject;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\NamespaceConfig;
use Axon\ReBAC\RelationRule;
use Axon\ReBAC\UsersetRewrite;
use Axon\ReBAC\UnionRewrite;
use Axon\ReBAC\ThisRewrite;
use Axon\ReBAC\ComputedUsersetRewrite;

/**
 * BenchCommand executes high-concurrency micro-benchmarks measuring ReBAC throughput and latency.
 */
final class BenchCommand implements Command {
  public function getName(): string {
    return 'bench';
  }

  public function getDescription(): string {
    return 'Run synthetic throughput and latency micro-benchmarks';
  }

  public function execute(vec<string> $args): int {
    $iterations = 50000;
    if (\count($args) >= 1 && \is_numeric($args[0])) {
      $iterations = (int)$args[0];
    }

    \printf("=== Axon Performance Micro-Benchmark ===\n");
    \printf("Benchmarking Zanzibar ReBAC Check Engine (%d iterations)...\n", $iterations);

    // Setup benchmark environment
    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();

    $docNs = new NamespaceConfig('document');
    $docNs->addRule(new RelationRule('viewer', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('editor'),
    ])));
    $docNs->addRule(new RelationRule('editor', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('owner'),
    ])));
    $docNs->addRule(new RelationRule('owner', new ThisRewrite()));
    $policies->registerNamespace($docNs);

    $alice = new Subject('user', 'alice');
    $store->insert(new RelationTuple('document', 'doc-1', 'owner', $alice));

    $checker = new CheckEngine($policies, $store);
    $req = new CheckRequest('document', 'doc-1', 'viewer', $alice);

    $start = \microtime(true);
    for ($i = 0; $i < $iterations; $i++) {
      $resp = $checker->check($req);
      if (!$resp->isAllowed()) {
        \fprintf(\STDERR, "Benchmark assertion failed at iteration %d\n", $i);
        return 1;
      }
    }
    $duration = \microtime(true) - $start;
    $opsPerSec = (float)$iterations / $duration;
    $avgMicros = ($duration / (float)$iterations) * 1000000.0;

    \printf("Completed %d checks in %.4f seconds\n", $iterations, $duration);
    \printf("Throughput: %.2f ops/sec\n", $opsPerSec);
    \printf("Average Latency: %.3f microseconds/op\n", $avgMicros);
    \printf("=========================================\n");

    return 0;
  }
}
