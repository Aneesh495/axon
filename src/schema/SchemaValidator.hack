namespace Axon\Schema;

use Axon\Core\Result;

/**
 * SchemaValidator performs deep structural integrity verification across all entities,
 * detecting unresolved target entities, foreign key inconsistencies, and missing inverse associations.
 */
final class SchemaValidator {
  public function validate(SchemaRegistry $registry): Result<bool, vec<string>> {
    $errors = vec[];
    $entities = $registry->getAllEntities();

    foreach ($entities as $entityName => $entity) {
      // 1. Verify primary key existence
      if ($entity->getPrimaryField() === null) {
        $errors[] = \sprintf('Entity "%s" does not declare a primary key field', $entityName);
      }

      // 2. Validate all declared edges
      foreach ($entity->getEdges() as $edgeName => $edge) {
        $targetName = $edge->getTargetEntity();

        // Target entity must exist in the registry
        if (!$registry->hasEntity($targetName)) {
          $errors[] = \sprintf(
            'Entity "%s" edge "%s" references undefined target entity "%s"',
            $entityName,
            $edgeName,
            $targetName
          );
          continue;
        }

        $targetEntity = $entities[$targetName];

        // If a foreign key is declared on this entity, verify the column exists
        $fk = $edge->getForeignKey();
        if ($fk !== null) {
          if ($edge->isSingular() && $entity->getField($fk) === null) {
            $errors[] = \sprintf(
              'Entity "%s" edge "%s" specifies missing foreign key column "%s"',
              $entityName,
              $edgeName,
              $fk
            );
          }
        }

        // If an inverse edge is specified, verify its existence and reciprocity on target entity
        $inverse = $edge->getInverseEdge();
        if ($inverse !== null) {
          $targetEdge = $targetEntity->getEdge($inverse);
          if ($targetEdge === null) {
            $errors[] = \sprintf(
              'Entity "%s" edge "%s" references missing inverse edge "%s" on target "%s"',
              $entityName,
              $edgeName,
              $inverse,
              $targetName
            );
          } else if ($targetEdge->getTargetEntity() !== $entityName) {
            $errors[] = \sprintf(
              'Entity "%s" edge "%s" inverse "%s" on "%s" points back to "%s" instead of "%s"',
              $entityName,
              $edgeName,
              $inverse,
              $targetName,
              $targetEdge->getTargetEntity(),
              $entityName
            );
          }
        }
      }
    }

    if (\count($errors) > 0) {
      return Result::err($errors);
    }

    return Result::ok(true);
  }
}
