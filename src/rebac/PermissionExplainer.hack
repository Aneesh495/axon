namespace Axon\ReBAC;

/**
 * ExplanationNode captures an individual deduction step in the authorization decision chain.
 */
final class ExplanationNode implements \JsonSerializable {
  private string $description;
  private bool $passed;
  private vec<ExplanationNode> $children;

  public function __construct(string $description, bool $passed, vec<ExplanationNode> $children = vec[]) {
    $this->description = $description;
    $this->passed = $passed;
    $this->children = $children;
  }

  public function getDescription(): string {
    return $this->description;
  }

  public function isPassed(): bool {
    return $this->passed;
  }

  public function getChildren(): vec<ExplanationNode> {
    return $this->children;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'step' => $this->description,
      'passed' => $this->passed,
      'children' => $this->children,
    ];
  }
}

/**
 * PermissionExplainer generates human-readable decision provenance trees.
 */
final class PermissionExplainer {
  private CheckEngine $checker;

  public function __construct(CheckEngine $checker) {
    $this->checker = $checker;
  }

  public function explain(CheckRequest $req): ExplanationNode {
    $resp = $this->checker->check($req);
    $desc = \sprintf(
      'Subject "%s" %s permission "%s" on object "%s:%s"',
      $req->getSubject()->toString(),
      $resp->isAllowed() ? 'HAS' : 'DOES NOT HAVE',
      $req->getPermission(),
      $req->getNamespace(),
      $req->getObjectId()
    );

    $traceNodes = vec[];
    foreach ($resp->getTrace() as $t) {
      $traceNodes[] = new ExplanationNode($t, true);
    }

    return new ExplanationNode($desc, $resp->isAllowed(), $traceNodes);
  }
}
