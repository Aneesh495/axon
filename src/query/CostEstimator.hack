namespace Axon\Query;

use Axon\Core\Result;

/**
 * CostEstimator computes static query complexity scores defending against denial-of-service queries.
 */
final class CostEstimator {
  private int $maxAllowedCost;
  private int $maxDepth;
  private int $scalarCost;
  private int $edgeCostMultiplier;

  public function __construct(
    int $maxAllowedCost = 1000,
    int $maxDepth = 15,
    int $scalarCost = 1,
    int $edgeCostMultiplier = 10
  ) {
    $this->maxAllowedCost = $maxAllowedCost;
    $this->maxDepth = $maxDepth;
    $this->scalarCost = $scalarCost;
    $this->edgeCostMultiplier = $edgeCostMultiplier;
  }

  public function estimate(DocumentNode $doc): Result<int, string> {
    $totalCost = 0;

    foreach ($doc->getOperations() as $op) {
      $cost = $this->calculateSetCost($op->getSelectionSet(), 1);
      $totalCost += $cost;
      if ($totalCost > $this->maxAllowedCost) {
        return Result::err(\sprintf('Query cost %d exceeds maximum allowable cost of %d', $totalCost, $this->maxAllowedCost));
      }
    }

    return Result::ok($totalCost);
  }

  private function calculateSetCost(SelectionSet $set, int $depth): int {
    if ($depth > $this->maxDepth) {
      throw new \RuntimeException(\sprintf('Query depth %d exceeds maximum depth threshold of %d', $depth, $this->maxDepth));
    }

    $cost = 0;
    foreach ($set->getSelections() as $sel) {
      if ($sel is FieldNode) {
        $field = $sel as FieldNode;
        $subSet = $field->getSelectionSet();
        if ($subSet === null) {
          $cost += $this->scalarCost;
        } else {
          $subCost = $this->calculateSetCost($subSet, $depth + 1);
          $cost += ($subCost * $this->edgeCostMultiplier);
        }
      }
    }
    return $cost;
  }
}
