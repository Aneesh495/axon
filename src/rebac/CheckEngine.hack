namespace Axon\ReBAC;

use Axon\Core\Result;

/**
 * CheckRequest encapsulates the parameters for an authorization check.
 */
final class CheckRequest {
  private string $namespace;
  private string $objectId;
  private string $permission;
  private Subject $subject;
  private ?vec<RelationTuple> $contextualTuples;

  public function __construct(
    string $namespace,
    string $objectId,
    string $permission,
    Subject $subject,
    ?vec<RelationTuple> $contextualTuples = null
  ) {
    $this->namespace = $namespace;
    $this->objectId = $objectId;
    $this->permission = $permission;
    $this->subject = $subject;
    $this->contextualTuples = $contextualTuples;
  }

  public function getNamespace(): string {
    return $this->namespace;
  }

  public function getObjectId(): string {
    return $this->objectId;
  }

  public function getPermission(): string {
    return $this->permission;
  }

  public function getSubject(): Subject {
    return $this->subject;
  }

  public function getContextualTuples(): ?vec<RelationTuple> {
    return $this->contextualTuples;
  }
}

/**
 * CheckResponse encapsulates the decision, evaluation depth, and diagnostic trace.
 */
final class CheckResponse {
  private bool $allowed;
  private int $depth;
  private vec<string> $trace;

  public function __construct(bool $allowed, int $depth, vec<string> $trace = vec[]) {
    $this->allowed = $allowed;
    $this->depth = $depth;
    $this->trace = $trace;
  }

  public function isAllowed(): bool {
    return $this->allowed;
  }

  public function getDepth(): int {
    return $this->depth;
  }

  public function getTrace(): vec<string> {
    return $this->trace;
  }
}

/**
 * TupleStore interface for querying relation assertions.
 */
interface TupleStore {
  public function readTuples(
    string $namespace,
    string $objectId,
    ?string $relation = null
  ): vec<RelationTuple>;

  public function readReverseTuples(
    Subject $subject,
    string $targetNamespace,
    string $relation
  ): vec<RelationTuple>;
}

/**
 * In-memory implementation of TupleStore for ultra-fast checks and tests.
 */
final class MemoryTupleStore implements TupleStore {
  private vec<RelationTuple> $tuples;

  public function __construct(vec<RelationTuple> $tuples = vec[]) {
    $this->tuples = $tuples;
  }

  public function insert(RelationTuple $tuple): void {
    foreach ($this->tuples as $t) {
      if ($t->equals($tuple)) {
        return;
      }
    }
    $this->tuples[] = $tuple;
  }

  public function delete(RelationTuple $tuple): void {
    $filtered = vec[];
    foreach ($this->tuples as $t) {
      if (!$t->equals($tuple)) {
        $filtered[] = $t;
      }
    }
    $this->tuples = $filtered;
  }

  public function readTuples(
    string $namespace,
    string $objectId,
    ?string $relation = null
  ): vec<RelationTuple> {
    $res = vec[];
    foreach ($this->tuples as $t) {
      if ($t->getNamespace() === $namespace && $t->getObjectId() === $objectId) {
        if ($relation === null || $t->getRelation() === $relation) {
          $res[] = $t;
        }
      }
    }
    return $res;
  }

  public function readReverseTuples(
    Subject $subject,
    string $targetNamespace,
    string $relation
  ): vec<RelationTuple> {
    $res = vec[];
    foreach ($this->tuples as $t) {
      if ($t->getNamespace() === $targetNamespace && $t->getRelation() === $relation) {
        if ($t->getSubject()->equals($subject)) {
          $res[] = $t;
        }
      }
    }
    return $res;
  }

  public function count(): int {
    return \count($this->tuples);
  }
}

/**
 * CheckEngine executes recursive Zanzibar relationship-based access control checks.
 * Features:
 * - Visited set cycle memoization to prevent infinite loops in cyclic graphs
 * - Configurable maximum recursion depth
 * - Short-circuiting boolean evaluation for union and intersection nodes
 * - Contextual tuple overlays per request
 */
final class CheckEngine {
  private PolicyRegistry $policies;
  private TupleStore $store;
  private int $maxDepth;

  public function __construct(
    PolicyRegistry $policies,
    TupleStore $store,
    int $maxDepth = 32
  ) {
    $this->policies = $policies;
    $this->store = $store;
    $this->maxDepth = $maxDepth;
  }

  public function check(CheckRequest $req): CheckResponse {
    $visited = dict[];
    $trace = vec[];
    $depth = 0;

    $allowed = $this->evaluate(
      $req->getNamespace(),
      $req->getObjectId(),
      $req->getPermission(),
      $req->getSubject(),
      $req->getContextualTuples(),
      $visited,
      $depth,
      $trace
    );

    return new CheckResponse($allowed, $depth, $trace);
  }

  private function evaluate(
    string $namespace,
    string $objectId,
    string $relation,
    Subject $subject,
    ?vec<RelationTuple> $contextual,
    dict<string, bool> $visited,
    int $depth,
    vec<string> $trace
  ): bool {
    if ($depth > $this->maxDepth) {
      $trace[] = \sprintf('MAX DEPTH REACHED at %s:%s#%s', $namespace, $objectId, $relation);
      return false;
    }

    $stateKey = \sprintf('%s:%s#%s@%s', $namespace, $objectId, $relation, $subject->toString());
    if (\array_key_exists($stateKey, $visited)) {
      // Cycle detected along current evaluation branch
      $trace[] = \sprintf('CYCLE DETECTED: %s', $stateKey);
      return false;
    }
    $visited[$stateKey] = true;

    $nsConfig = $this->policies->getNamespace($namespace);
    if ($nsConfig === null) {
      $trace[] = \sprintf('UNKNOWN NAMESPACE: %s', $namespace);
      return false;
    }

    $rule = $nsConfig->getRule($relation);
    if ($rule === null) {
      // If no explicit rewrite rule is registered, fall back to direct tuple matching
      return $this->checkDirectTuple($namespace, $objectId, $relation, $subject, $contextual);
    }

    return $this->evaluateRewrite(
      $namespace,
      $objectId,
      $rule->getRewrite(),
      $subject,
      $contextual,
      $visited,
      $depth + 1,
      $trace
    );
  }

  private function evaluateRewrite(
    string $namespace,
    string $objectId,
    UsersetRewrite $rewrite,
    Subject $subject,
    ?vec<RelationTuple> $contextual,
    dict<string, bool> $visited,
    int $depth,
    vec<string> $trace
  ): bool {
    switch ($rewrite->getType()) {
      case RewriteType::THIS:
        return $this->checkDirectTuple($namespace, $objectId, '', $subject, $contextual);

      case RewriteType::COMPUTED_USERSET:
        $cu = $rewrite as ComputedUsersetRewrite;
        return $this->evaluate(
          $namespace,
          $objectId,
          $cu->getRelation(),
          $subject,
          $contextual,
          $visited,
          $depth,
          $trace
        );

      case RewriteType::TUPLE_TO_USERSET:
        $ttu = $rewrite as TupleToUsersetRewrite;
        return $this->evaluateTupleToUserset(
          $namespace,
          $objectId,
          $ttu->getTuplesetRelation(),
          $ttu->getComputedRelation(),
          $subject,
          $contextual,
          $visited,
          $depth,
          $trace
        );

      case RewriteType::UNION:
        $union = $rewrite as UnionRewrite;
        foreach ($union->getChildren() as $child) {
          if ($this->evaluateRewrite($namespace, $objectId, $child, $subject, $contextual, $visited, $depth, $trace)) {
            return true;
          }
        }
        return false;

      case RewriteType::INTERSECTION:
        $intersection = $rewrite as IntersectionRewrite;
        foreach ($intersection->getChildren() as $child) {
          if (!$this->evaluateRewrite($namespace, $objectId, $child, $subject, $contextual, $visited, $depth, $trace)) {
            return false;
          }
        }
        return true;

      case RewriteType::EXCLUSION:
        $exclusion = $rewrite as ExclusionRewrite;
        $baseResult = $this->evaluateRewrite(
          $namespace,
          $objectId,
          $exclusion->getBase(),
          $subject,
          $contextual,
          $visited,
          $depth,
          $trace
        );
        if (!$baseResult) {
          return false;
        }
        $subResult = $this->evaluateRewrite(
          $namespace,
          $objectId,
          $exclusion->getSubtract(),
          $subject,
          $contextual,
          $visited,
          $depth,
          $trace
        );
        return !$subResult;
    }
  }

  private function checkDirectTuple(
    string $namespace,
    string $objectId,
    string $relation,
    Subject $subject,
    ?vec<RelationTuple> $contextual
  ): bool {
    // 1. Check contextual tuples first
    if ($contextual !== null) {
      foreach ($contextual as $t) {
        if ($t->getNamespace() === $namespace &&
            $t->getObjectId() === $objectId &&
            ($relation === '' || $t->getRelation() === $relation)) {
          if ($t->getSubject()->equals($subject)) {
            return true;
          }
        }
      }
    }

    // 2. Query persistent tuple store
    $storedTuples = $this->store->readTuples($namespace, $objectId, $relation === '' ? null : $relation);
    foreach ($storedTuples as $t) {
      if ($t->getSubject()->equals($subject)) {
        return true;
      }
      // Check for userset indirection in stored tuple subject
      if ($t->getSubject()->isUserset()) {
        $subNs = $t->getSubject()->getNamespace();
        $subId = $t->getSubject()->getId();
        $subRel = $t->getSubject()->getRelation() as nonnull;

        $subCheck = $this->evaluate(
          $subNs,
          $subId,
          $subRel,
          $subject,
          $contextual,
          dict[],
          0,
          vec[]
        );
        if ($subCheck) {
          return true;
        }
      }
    }

    return false;
  }

  private function evaluateTupleToUserset(
    string $namespace,
    string $objectId,
    string $tuplesetRelation,
    string $computedRelation,
    Subject $subject,
    ?vec<RelationTuple> $contextual,
    dict<string, bool> $visited,
    int $depth,
    vec<string> $trace
  ): bool {
    $tuples = $this->store->readTuples($namespace, $objectId, $tuplesetRelation);
    if ($contextual !== null) {
      foreach ($contextual as $ct) {
        if ($ct->getNamespace() === $namespace &&
            $ct->getObjectId() === $objectId &&
            $ct->getRelation() === $tuplesetRelation) {
          $tuples[] = $ct;
        }
      }
    }

    foreach ($tuples as $t) {
      $targetNs = $t->getSubject()->getNamespace();
      $targetId = $t->getSubject()->getId();

      if ($this->evaluate($targetNs, $targetId, $computedRelation, $subject, $contextual, $visited, $depth + 1, $trace)) {
        return true;
      }
    }

    return false;
  }
}
