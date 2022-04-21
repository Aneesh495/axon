namespace Axon\Schema;

/**
 * Cardinality of associations between graph entities.
 */
enum EdgeCardinality: string {
  ONE_TO_ONE = 'ONE_TO_ONE';
  ONE_TO_MANY = 'ONE_TO_MANY';
  MANY_TO_ONE = 'MANY_TO_ONE';
  MANY_TO_MANY = 'MANY_TO_MANY';
}

/**
 * Cascade actions applied when the parent node of an association is deleted.
 */
enum OnDeleteAction: string {
  CASCADE = 'CASCADE';
  SET_NULL = 'SET_NULL';
  RESTRICT = 'RESTRICT';
}

/**
 * EdgeDefinition represents a directed association between two entities in the graph schema.
 */
final class EdgeDefinition {
  private string $name;
  private string $sourceEntity;
  private string $targetEntity;
  private EdgeCardinality $cardinality;
  private ?string $foreignKey;
  private ?string $joinTable;
  private ?string $inverseEdge;
  private OnDeleteAction $onDelete;
  private string $description;

  public function __construct(
    string $name,
    string $sourceEntity,
    string $targetEntity,
    EdgeCardinality $cardinality,
    ?string $foreignKey = null,
    ?string $joinTable = null,
    ?string $inverseEdge = null,
    OnDeleteAction $onDelete = OnDeleteAction::RESTRICT,
    string $description = ''
  ) {
    $this->name = $name;
    $this->sourceEntity = $sourceEntity;
    $this->targetEntity = $targetEntity;
    $this->cardinality = $cardinality;
    $this->foreignKey = $foreignKey;
    $this->joinTable = $joinTable;
    $this->inverseEdge = $inverseEdge;
    $this->onDelete = $onDelete;
    $this->description = $description;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getSourceEntity(): string {
    return $this->sourceEntity;
  }

  public function getTargetEntity(): string {
    return $this->targetEntity;
  }

  public function getCardinality(): EdgeCardinality {
    return $this->cardinality;
  }

  public function getForeignKey(): ?string {
    return $this->foreignKey;
  }

  public function getJoinTable(): ?string {
    return $this->joinTable;
  }

  public function getInverseEdge(): ?string {
    return $this->inverseEdge;
  }

  public function getOnDelete(): OnDeleteAction {
    return $this->onDelete;
  }

  public function getDescription(): string {
    return $this->description;
  }

  public function isSingular(): bool {
    return $this->cardinality === EdgeCardinality::ONE_TO_ONE ||
           $this->cardinality === EdgeCardinality::MANY_TO_ONE;
  }

  public function isPlural(): bool {
    return $this->cardinality === EdgeCardinality::ONE_TO_MANY ||
           $this->cardinality === EdgeCardinality::MANY_TO_MANY;
  }
}
