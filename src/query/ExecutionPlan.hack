namespace Axon\Query;

/**
 * ExecutionStepType differentiates between scalar leaf resolution,
 * local entity edge joins, and remote federated subgraph fetches.
 */
enum ExecutionStepType: string {
  LOCAL_SCAN = 'LOCAL_SCAN';
  POINT_LOOKUP = 'POINT_LOOKUP';
  EDGE_EXPANSION = 'EDGE_EXPANSION';
  FEDERATED_SUBGRAPH = 'FEDERATED_SUBGRAPH';
}

/**
 * ExecutionPlanNode represents a single planned step in the query execution DAG.
 */
final class ExecutionPlanNode {
  private string $id;
  private ExecutionStepType $stepType;
  private string $entityName;
  private vec<string> $projectedFields;
  private dict<string, mixed> $arguments;
  private vec<ExecutionPlanNode> $children;
  private ?string $subgraphEndpoint;

  public function __construct(
    string $id,
    ExecutionStepType $stepType,
    string $entityName,
    vec<string> $projectedFields = vec[],
    dict<string, mixed> $arguments = dict[],
    vec<ExecutionPlanNode> $children = vec[],
    ?string $subgraphEndpoint = null
  ) {
    $this->id = $id;
    $this->stepType = $stepType;
    $this->entityName = $entityName;
    $this->projectedFields = $projectedFields;
    $this->arguments = $arguments;
    $this->children = $children;
    $this->subgraphEndpoint = $subgraphEndpoint;
  }

  public function getId(): string {
    return $this->id;
  }

  public function getStepType(): ExecutionStepType {
    return $this->stepType;
  }

  public function getEntityName(): string {
    return $this->entityName;
  }

  public function getProjectedFields(): vec<string> {
    return $this->projectedFields;
  }

  public function getArguments(): dict<string, mixed> {
    return $this->arguments;
  }

  public function getChildren(): vec<ExecutionPlanNode> {
    return $this->children;
  }

  public function getSubgraphEndpoint(): ?string {
    return $this->subgraphEndpoint;
  }
}

/**
 * Complete ExecutionPlan produced by the query planner.
 */
final class ExecutionPlan {
  private vec<ExecutionPlanNode> $rootNodes;
  private int $estimatedCost;

  public function __construct(vec<ExecutionPlanNode> $rootNodes, int $estimatedCost = 1) {
    $this->rootNodes = $rootNodes;
    $this->estimatedCost = $estimatedCost;
  }

  public function getRootNodes(): vec<ExecutionPlanNode> {
    return $this->rootNodes;
  }

  public function getEstimatedCost(): int {
    return $this->estimatedCost;
  }
}
