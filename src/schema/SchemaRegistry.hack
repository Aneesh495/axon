namespace Axon\Schema;

use Axon\Core\Result;

/**
 * SchemaRegistry stores, compiles, and retrieves entity and association definitions
 * across the entire federated system graph.
 */
final class SchemaRegistry {
  private dict<string, EntityDefinition> $entities;

  public function __construct() {
    $this->entities = dict[];
  }

  public function registerEntity(EntityDefinition $entity): void {
    $this->entities[$entity->getName()] = $entity;
  }

  public function getEntity(string $name): ?EntityDefinition {
    return \array_key_exists($name, $this->entities) ? $this->entities[$name] : null;
  }

  public function hasEntity(string $name): bool {
    return \array_key_exists($name, $this->entities);
  }

  public function getAllEntities(): dict<string, EntityDefinition> {
    return $this->entities;
  }

  /**
   * Compiles and validates all registered entities, ensuring cross-references
   * and foreign keys are consistent.
   */
  public function compile(): Result<bool, vec<string>> {
    $validator = new SchemaValidator();
    return $validator->validate($this);
  }
}
