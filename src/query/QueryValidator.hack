namespace Axon\Query;

use Axon\Core\Result;
use Axon\Schema\SchemaRegistry;
use Axon\Schema\EntityDefinition;

/**
 * QueryValidator verifies that parsed query AST operations, fields, and arguments
 * conform strictly to registered entity schemas and types.
 */
final class QueryValidator {
  private SchemaRegistry $registry;

  public function __construct(SchemaRegistry $registry) {
    $this->registry = $registry;
  }

  public function validate(DocumentNode $document): Result<bool, vec<string>> {
    $errors = vec[];

    foreach ($document->getOperations() as $op) {
      $opErrors = $this->validateOperation($op);
      foreach ($opErrors as $err) {
        $errors[] = $err;
      }
    }

    if (\count($errors) > 0) {
      return Result::err($errors);
    }

    return Result::ok(true);
  }

  private function validateOperation(OperationDefinition $op): vec<string> {
    $errors = vec[];
    $set = $op->getSelectionSet();

    foreach ($set->getSelections() as $selection) {
      if ($selection is FieldNode) {
        $field = $selection as FieldNode;
        $rootName = $field->getName();

        // Check if root field is an entity query or known system field
        if (!$this->registry->hasEntity($rootName) && $rootName !== '__schema' && $rootName !== 'node') {
          $errors[] = \sprintf('Unknown root entity or query field "%s" at line %d', $rootName, $field->getLine());
          continue;
        }

        if ($this->registry->hasEntity($rootName)) {
          $entity = $this->registry->getEntity($rootName) as nonnull;
          $subSet = $field->getSelectionSet();
          if ($subSet === null) {
            $errors[] = \sprintf('Entity query "%s" must specify a selection set', $rootName);
          } else {
            $subErrors = $this->validateEntitySelectionSet($entity, $subSet);
            foreach ($subErrors as $subErr) {
              $errors[] = $subErr;
            }
          }
        }
      }
    }

    return $errors;
  }

  private function validateEntitySelectionSet(EntityDefinition $entity, SelectionSet $set): vec<string> {
    $errors = vec[];

    foreach ($set->getSelections() as $selection) {
      if ($selection is FieldNode) {
        $field = $selection as FieldNode;
        $name = $field->getName();

        if ($name === 'id' || $name === '__typename') {
          continue;
        }

        $fieldDef = $entity->getField($name);
        $edgeDef = $entity->getEdge($name);

        if ($fieldDef === null && $edgeDef === null) {
          $errors[] = \sprintf(
            'Field "%s" does not exist on entity "%s" (line %d)',
            $name,
            $entity->getName(),
            $field->getLine()
          );
          continue;
        }

        // If it is an edge association, it must have a child selection set
        if ($edgeDef !== null) {
          $subSet = $field->getSelectionSet();
          if ($subSet === null) {
            $errors[] = \sprintf(
              'Association edge "%s" on entity "%s" requires a nested selection set',
              $name,
              $entity->getName()
            );
          } else {
            $targetEntity = $this->registry->getEntity($edgeDef->getTargetEntity());
            if ($targetEntity !== null) {
              $subErrors = $this->validateEntitySelectionSet($targetEntity, $subSet);
              foreach ($subErrors as $se) {
                $errors[] = $se;
              }
            }
          }
        } else if ($fieldDef !== null) {
          // Scalar fields must not have a child selection set
          if ($field->getSelectionSet() !== null) {
            $errors[] = \sprintf(
              'Scalar field "%s" on entity "%s" cannot have sub-selections',
              $name,
              $entity->getName()
            );
          }
        }
      }
    }

    return $errors;
  }
}
