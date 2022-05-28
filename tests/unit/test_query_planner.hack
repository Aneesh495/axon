namespace Axon\Tests\Unit;

use Axon\Query\QueryParser;
use Axon\Query\QueryPlanner;
use Axon\Query\ExecutionStepType;
use Axon\Schema\SchemaRegistry;

final class TestQueryPlanner {
  public static function run(): void {
    \printf("Running TestQueryPlanner...\n");

    $registry = new SchemaRegistry();
    $planner = new QueryPlanner($registry);

    $query = '{ Document(id: "doc-1") { title content } }';
    $doc = QueryParser::parse($query)->unwrap();

    $plan = $planner->plan($doc);
    $roots = $plan->getRootNodes();

    if (\count($roots) !== 1) {
      throw new \RuntimeException("Expected 1 root execution plan step");
    }

    $step = $roots[0];
    if ($step->getStepType() !== ExecutionStepType::POINT_LOOKUP) {
      throw new \RuntimeException("Expected POINT_LOOKUP step for query with id argument");
    }

    $projected = $step->getProjectedFields();
    if (\count($projected) !== 2 || $projected[0] !== 'title' || $projected[1] !== 'content') {
      throw new \RuntimeException("Projected fields mismatch in execution step");
    }

    \printf("TestQueryPlanner passed.\n");
  }
}
