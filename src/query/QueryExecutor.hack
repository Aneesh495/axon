namespace Axon\Query;

use Axon\ReBAC\ViewerContext;
use Axon\DataLoader\DataLoaderRegistry;
use Axon\Schema\SchemaRegistry;

/**
 * ExecutionResult contains the resolved query response data payload and error list.
 */
final class ExecutionResult implements \JsonSerializable {
  private dict<string, mixed> $data;
  private vec<string> $errors;

  public function __construct(dict<string, mixed> $data, vec<string> $errors = vec[]) {
    $this->data = $data;
    $this->errors = $errors;
  }

  public function getData(): dict<string, mixed> {
    return $this->data;
  }

  public function getErrors(): vec<string> {
    return $this->errors;
  }

  public function hasErrors(): bool {
    return \count($this->errors) > 0;
  }

  public function jsonSerialize(): dict<string, mixed> {
    $res = dict['data' => $this->data];
    if (\count($this->errors) > 0) {
      $res['errors'] = $this->errors;
    }
    return $res;
  }
}

/**
 * QueryExecutor evaluates ExecutionPlans using DataLoader batching and ReBAC privacy enforcement.
 */
final class QueryExecutor {
  private SchemaRegistry $schema;
  private FieldResolver $resolver;

  public function __construct(SchemaRegistry $schema, FieldResolver $resolver) {
    $this->schema = $schema;
    $this->resolver = $resolver;
  }

  public function execute(
    ExecutionPlan $plan,
    ViewerContext $viewer,
    DataLoaderRegistry $loaders
  ): ExecutionResult {
    $data = dict[];
    $errors = vec[];

    foreach ($plan->getRootNodes() as $step) {
      $entityName = $step->getEntityName();
      $args = $step->getArguments();

      if (\array_key_exists('id', $args)) {
        // Point lookup
        $targetId = (string)$args['id'];
        $loader = $loaders->getEntityLoader($entityName);

        if ($loader !== null) {
          $deferred = $loader->load($targetId);
          $loaders->dispatchAll();

          try {
            $rawRecord = $deferred->awaitResult();
            if ($rawRecord !== null) {
              $resolved = $this->resolver->resolveRecord(
                $viewer,
                \strtolower($entityName),
                $rawRecord,
                $step->getProjectedFields()
              );
              $data[$entityName] = $resolved;
            } else {
              $data[$entityName] = null;
            }
          } catch (\Throwable $e) {
            $errors[] = $e->getMessage();
            $data[$entityName] = null;
          }
        } else {
          $errors[] = \sprintf('No DataLoader registered for entity "%s"', $entityName);
          $data[$entityName] = null;
        }
      }
    }

    return new ExecutionResult($data, $errors);
  }
}
