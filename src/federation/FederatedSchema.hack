namespace Axon\Federation;

/**
 * SubgraphDefinition records metadata, endpoint, and owned entities for an upstream service.
 */
final class SubgraphDefinition {
  private string $name;
  private string $endpointUrl;
  private vec<string> $ownedEntities;
  private dict<string, vec<string>> $extendedFields;

  public function __construct(
    string $name,
    string $endpointUrl,
    vec<string> $ownedEntities = vec[],
    dict<string, vec<string>> $extendedFields = dict[]
  ) {
    $this->name = $name;
    $this->endpointUrl = $endpointUrl;
    $this->ownedEntities = $ownedEntities;
    $this->extendedFields = $extendedFields;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getEndpointUrl(): string {
    return $this->endpointUrl;
  }

  public function getOwnedEntities(): vec<string> {
    return $this->ownedEntities;
  }

  public function getExtendedFields(): dict<string, vec<string>> {
    return $this->extendedFields;
  }
}

/**
 * FederatedSchema represents the stitched supergraph configuration.
 */
final class FederatedSchema {
  private dict<string, SubgraphDefinition> $subgraphs;
  private dict<string, string> $entityOwners;

  public function __construct() {
    $this->subgraphs = dict[];
    $this->entityOwners = dict[];
  }

  public function registerSubgraph(SubgraphDefinition $subgraph): void {
    $this->subgraphs[$subgraph->getName()] = $subgraph;
    foreach ($subgraph->getOwnedEntities() as $entity) {
      $this->entityOwners[$entity] = $subgraph->getName();
    }
  }

  public function getSubgraph(string $name): ?SubgraphDefinition {
    return \array_key_exists($name, $this->subgraphs) ? $this->subgraphs[$name] : null;
  }

  public function getEntityOwner(string $entityName): ?string {
    return \array_key_exists($entityName, $this->entityOwners) ? $this->entityOwners[$entityName] : null;
  }

  public function getAllSubgraphs(): dict<string, SubgraphDefinition> {
    return $this->subgraphs;
  }
}
