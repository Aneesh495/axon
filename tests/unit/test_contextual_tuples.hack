namespace Axon\Tests\Unit;

use Axon\ReBAC\ContextualTupleEngine;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\Subject;

final class TestContextualTuples {
  public static function run(): void {
    \printf("Running TestContextualTuples...\n");

    $engine = new ContextualTupleEngine();
    $tuple = new RelationTuple('server', 'srv-1', 'operator', new Subject('user', 'oncall'));

    // Add with 10 second TTL at t = 1000ms
    $engine->addEphemeralTuple($tuple, 10, 1000);

    // Active at t = 5000ms
    $active = $engine->getActiveTuples(5000);
    if (\count($active) !== 1) {
      throw new \RuntimeException("Ephemeral tuple should be active before expiration");
    }

    // Expired at t = 12000ms
    $expired = $engine->getActiveTuples(12000);
    if (\count($expired) !== 0) {
      throw new \RuntimeException("Ephemeral tuple should be inactive after expiration");
    }

    \printf("TestContextualTuples passed.\n");
  }
}
