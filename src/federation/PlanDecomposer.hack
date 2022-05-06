namespace Axon\Federation;

use Axon\Query\DocumentNode;
use Axon\Query\FieldNode;

/**
 * SubgraphTask encapsulates a query fragment destined for a specific upstream subgraph.
 */
final class SubgraphTask {
  private string $subgraphName;
  private string $query;
  private dict<string, mixed> $variables;

  public function __construct(
    string $subgraphName,
    string $query,
    dict<string, mixed> $variables = dict[]
  ) {
    $this->subgraphName = $subgraphName;
    $this->query = $query;
    $this->variables = $variables;
  }

  public function getSubgraphName(): string {
    return $this->subgraphName;
  }

  public function getQuery(): string {
    return $this->query;
  }

  public function getVariables(): dict<string, mixed> {
    return $this->variables;
  }
}

/**
 * PlanDecomposer partitions a supergraph query into independent subgraph tasks.
 */
final class PlanDecomposer {
  private FederatedSchema $federatedSchema;

  public function __construct(FederatedSchema $federatedSchema) {
    $this->federatedSchema = $federatedSchema;
  }

  public function decompose(DocumentNode $document): vec<SubgraphTask> {
    $tasks = vec[];
    $op = $document->getPrimaryOperation();
    if ($op === null) {
      return $tasks;
    }

    foreach ($op->getSelectionSet()->getSelections() as $sel) {
      if ($sel is FieldNode) {
        $field = $sel as FieldNode;
        $name = $field->getName();
        $subgraphName = $this->federatedSchema->getEntityOwner($name) ?? 'core';

        $fieldQuery = \sprintf('{ %s { id } }', $name);
        $tasks[] = new SubgraphTask($subgraphName, $fieldQuery);
      }
    }

    return $tasks;
  }
}
