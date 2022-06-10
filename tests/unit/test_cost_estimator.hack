namespace Axon\Tests\Unit;

use Axon\Query\QueryParser;
use Axon\Query\CostEstimator;

final class TestCostEstimator {
  public static function run(): void {
    \printf("Running TestCostEstimator...\n");

    $estimator = new CostEstimator(100, 5);

    $simpleQuery = '{ Document(id: "doc-1") { title content } }';
    $doc = QueryParser::parse($simpleQuery)->unwrap();

    $costRes = $estimator->estimate($doc);
    if ($costRes->isErr()) {
      throw new \RuntimeException("Valid query should not exceed cost: " . $costRes->unwrapErr());
    }

    if ($costRes->unwrap() <= 0) {
      throw new \RuntimeException("Estimated cost must be positive");
    }

    // Overly nested query exceeding depth limit of 5
    $deepQuery = '{ a { b { c { d { e { f { g } } } } } } }';
    $deepDoc = QueryParser::parse($deepQuery)->unwrap();

    $exceeded = false;
    try {
      $estimator->estimate($deepDoc);
    } catch (\Throwable $e) {
      $exceeded = true;
    }

    if (!$exceeded) {
      throw new \RuntimeException("Deep query should have triggered depth limit violation");
    }

    \printf("TestCostEstimator passed.\n");
  }
}
