namespace Axon\ReBAC;

/**
 * UsersetRewriteType defines the operator used in permission rule evaluation.
 */
enum RewriteType: string {
  THIS = 'THIS';
  COMPUTED_USERSET = 'COMPUTED_USERSET';
  TUPLE_TO_USERSET = 'TUPLE_TO_USERSET';
  UNION = 'UNION';
  INTERSECTION = 'INTERSECTION';
  EXCLUSION = 'EXCLUSION';
}

/**
 * Abstract syntax tree node representing a Zanzibar permission rewrite rule.
 */
abstract class UsersetRewrite {
  abstract public function getType(): RewriteType;
}

/**
 * Direct relation check against explicit tuples in the storage index.
 */
final class ThisRewrite extends UsersetRewrite {
  <<__Override>>
  public function getType(): RewriteType {
    return RewriteType::THIS;
  }
}

/**
 * Userset computed from another relation on the same object node.
 * Example: "editor" includes everyone with relation "owner".
 */
final class ComputedUsersetRewrite extends UsersetRewrite {
  private string $relation;

  public function __construct(string $relation) {
    $this->relation = $relation;
  }

  public function getRelation(): string {
    return $this->relation;
  }

  <<__Override>>
  public function getType(): RewriteType {
    return RewriteType::COMPUTED_USERSET;
  }
}

/**
 * Userset computed via indirection through an association edge.
 * Example: "viewer" of a Document includes everyone who is a "viewer" of its parent "workspace".
 */
final class TupleToUsersetRewrite extends UsersetRewrite {
  private string $tuplesetRelation;
  private string $computedRelation;

  public function __construct(string $tuplesetRelation, string $computedRelation) {
    $this->tuplesetRelation = $tuplesetRelation;
    $this->computedRelation = $computedRelation;
  }

  public function getTuplesetRelation(): string {
    return $this->tuplesetRelation;
  }

  public function getComputedRelation(): string {
    return $this->computedRelation;
  }

  <<__Override>>
  public function getType(): RewriteType {
    return RewriteType::TUPLE_TO_USERSET;
  }
}

/**
 * Logical disjunction (OR) of multiple child rewrites.
 */
final class UnionRewrite extends UsersetRewrite {
  private vec<UsersetRewrite> $children;

  public function __construct(vec<UsersetRewrite> $children) {
    $this->children = $children;
  }

  public function getChildren(): vec<UsersetRewrite> {
    return $this->children;
  }

  <<__Override>>
  public function getType(): RewriteType {
    return RewriteType::UNION;
  }
}

/**
 * Logical conjunction (AND) of multiple child rewrites.
 */
final class IntersectionRewrite extends UsersetRewrite {
  private vec<UsersetRewrite> $children;

  public function __construct(vec<UsersetRewrite> $children) {
    $this->children = $children;
  }

  public function getChildren(): vec<UsersetRewrite> {
    return $this->children;
  }

  <<__Override>>
  public function getType(): RewriteType {
    return RewriteType::INTERSECTION;
  }
}

/**
 * Logical negation / set difference (base EXCEPT subtract).
 */
final class ExclusionRewrite extends UsersetRewrite {
  private UsersetRewrite $base;
  private UsersetRewrite $subtract;

  public function __construct(UsersetRewrite $base, UsersetRewrite $subtract) {
    $this->base = $base;
    $this->subtract = $subtract;
  }

  public function getBase(): UsersetRewrite {
    return $this->base;
  }

  public function getSubtract(): UsersetRewrite {
    return $this->subtract;
  }

  <<__Override>>
  public function getType(): RewriteType {
    return RewriteType::EXCLUSION;
  }
}
