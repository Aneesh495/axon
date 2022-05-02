namespace Axon\Query;

use Axon\ReBAC\ViewerContext;
use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;

/**
 * FieldResolver applies privacy filtering, field transformation, and authorization assertions.
 */
final class FieldResolver {
  private CheckEngine $checker;

  public function __construct(CheckEngine $checker) {
    $this->checker = $checker;
  }

  /**
   * Asserts whether the current viewer is authorized to inspect an entity node.
   */
  public function canViewNode(
    ViewerContext $viewer,
    string $namespace,
    string $objectId
  ): bool {
    if ($viewer->isOmnipotent()) {
      return true;
    }

    $req = new CheckRequest($namespace, $objectId, 'viewer', $viewer->toSubject());
    $resp = $this->checker->check($req);
    return $resp->isAllowed();
  }

  /**
   * Filters a record dictionary according to viewer field visibility policies.
   */
  public function resolveRecord(
    ViewerContext $viewer,
    string $namespace,
    dict<string, mixed> $record,
    vec<string> $projectedFields
  ): ?dict<string, mixed> {
    $id = (string)($record['id'] ?? '');
    if ($id !== '' && !$this->canViewNode($viewer, $namespace, $id)) {
      // Viewer denied access to this node; return null for privacy masking
      return null;
    }

    $out = dict[];
    if (\count($projectedFields) === 0) {
      return $record;
    }

    foreach ($projectedFields as $field) {
      if (\array_key_exists($field, $record)) {
        $out[$field] = $record[$field];
      }
    }

    // Always include id if present in record
    if (\array_key_exists('id', $record)) {
      $out['id'] = $record['id'];
    }

    return $out;
  }
}
