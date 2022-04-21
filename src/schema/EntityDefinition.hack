namespace Axon\Schema;

use Axon\Core\Result;

/**
 * SecondaryIndex defines composite or single-column indexes for fast lookups.
 */
final class IndexDefinition {
  private string $name;
  private vec<string> $columns;
  private bool $isUnique;

  public function __construct(string $name, vec<string> $columns, bool $isUnique = false) {
    $this->name = $name;
    $this->columns = $columns;
    $this->isUnique = $isUnique;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getColumns(): vec<string> {
    return $this->columns;
  }

  public function isUnique(): bool {
    return $this->isUnique;
  }
}

/**
 * EntityDefinition defines the complete schema contract for a domain entity node,
 * including its fields, associations, indexes, and authorization namespace binding.
 */
final class EntityDefinition {
  private string $name;
  private string $tableName;
  private dict<string, FieldDefinition> $fields;
  private dict<string, EdgeDefinition> $edges;
  private vec<IndexDefinition> $indexes;
  private ?string $rebacNamespace;
  private string $description;

  public function __construct(
    string $name,
    string $tableName,
    dict<string, FieldDefinition> $fields,
    dict<string, EdgeDefinition> $edges = dict[],
    vec<IndexDefinition> $indexes = vec[],
    ?string $rebacNamespace = null,
    string $description = ''
  ) {
    $this->name = $name;
    $this->tableName = $tableName;
    $this->fields = $fields;
    $this->edges = $edges;
    $this->indexes = $indexes;
    $this->rebacNamespace = $rebacNamespace;
    $this->description = $description;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getTableName(): string {
    return $this->tableName;
  }

  public function getFields(): dict<string, FieldDefinition> {
    return $this->fields;
  }

  public function getField(string $fieldName): ?FieldDefinition {
    return \array_key_exists($fieldName, $this->fields) ? $this->fields[$fieldName] : null;
  }

  public function getEdges(): dict<string, EdgeDefinition> {
    return $this->edges;
  }

  public function getEdge(string $edgeName): ?EdgeDefinition {
    return \array_key_exists($edgeName, $this->edges) ? $this->edges[$edgeName] : null;
  }

  public function getIndexes(): vec<IndexDefinition> {
    return $this->indexes;
  }

  public function getRebacNamespace(): ?string {
    return $this->rebacNamespace;
  }

  public function getDescription(): string {
    return $this->description;
  }

  public function getPrimaryField(): ?FieldDefinition {
    foreach ($this->fields as $field) {
      if ($field->isPrimary()) {
        return $field;
      }
    }
    return null;
  }

  /**
   * Validates a complete property dictionary against this entity definition.
   */
  public function validateRecord(dict<string, mixed> $record): Result<dict<string, mixed>, string> {
    $validated = dict[];

    foreach ($this->fields as $name => $def) {
      $val = \array_key_exists($name, $record) ? $record[$name] : null;
      $check = $def->validate($val);
      if ($check->isErr()) {
        return Result::err($check->unwrapErr());
      }
      $validated[$name] = $check->unwrap();
    }

    return Result::ok($validated);
  }
}
