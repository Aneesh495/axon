namespace Axon\Query;

use Axon\Schema\SchemaRegistry;

/**
 * QueryPlanner analyzes validated QueryASTs and derives optimal distributed execution plans,
 * organizing parallel resolution stages and partitioning federated subgraphs.
 */
final class QueryPlanner {
  private SchemaRegistry $registry;

  public function __construct(SchemaRegistry $registry) {
    $this->registry = $registry;
  }

  public function plan(DocumentNode $document): ExecutionPlan {
    $op = $document->getPrimaryOperation();
    if ($op === null) {
      return new ExecutionPlan(vec[], 0);
    }

    $rootNodes = vec[];
    $totalCost = 0;

    foreach ($op->getSelectionSet()->getSelections() as $sel) {
      if ($sel is FieldNode) {
        $field = $sel as FieldNode;
        $nodePlan = $this->planField($field, 1);
        $rootNodes[] = $nodePlan;
        $totalCost += 10;
      }
    }

    return new ExecutionPlan($rootNodes, $totalCost);
  }

  private function planField(FieldNode $field, int $depth): ExecutionPlanNode {
    $name = $field->getName();
    $stepType = ExecutionStepType::LOCAL_SCAN;

    if (\array_key_exists('id', $field->getArguments())) {
      $stepType = ExecutionStepType::POINT_LOOKUP;
    }

    $projected = vec[];
    $children = vec[];

    $subSet = $field->getSelectionSet();
    if ($subSet !== null) {
      foreach ($subSet->getSelections() as $subSel) {
        if ($subSel is FieldNode) {
          $subField = $subSel as FieldNode;
          if ($subField->getSelectionSet() === null) {
            $projected[] = $subField->getName();
          } else {
            $childNode = $this->planField($subField, $depth + 1);
            $children[] = $childNode;
          }
        }
      }
    }

    return new ExecutionPlanNode(
      \uniqid('step_'),
      $stepType,
      $name,
      $projected,
      $field->getArguments(),
      $children
    );
  }
}
