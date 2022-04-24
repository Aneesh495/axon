namespace Axon\ReBAC;

/**
 * ListObjectsEngine resolves all object IDs within a namespace that a given subject
 * possesses permissions to access.
 */
final class ListObjectsEngine {
  private CheckEngine $checker;
  private TupleStore $store;

  public function __construct(CheckEngine $checker, TupleStore $store) {
    $this->checker = $checker;
    $this->store = $store;
  }

  /**
   * Scans candidate objects in candidateList (or queries available tuples)
   * and filters by permission assertion.
   */
  public function listObjects(
    string $targetNamespace,
    string $permission,
    Subject $subject,
    vec<string> $candidateObjectIds
  ): vec<string> {
    $authorized = vec[];

    foreach ($candidateObjectIds as $objId) {
      $req = new CheckRequest($targetNamespace, $objId, $permission, $subject);
      $resp = $this->checker->check($req);
      if ($resp->isAllowed()) {
        $authorized[] = $objId;
      }
    }

    return $authorized;
  }
}
