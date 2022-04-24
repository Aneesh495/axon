namespace Axon\ReBAC;

/**
 * Node type in a permission userset expansion tree.
 */
enum ExpandNodeType: string {
  LEAF = 'LEAF';
  UNION = 'UNION';
  INTERSECTION = 'INTERSECTION';
  EXCLUSION = 'EXCLUSION';
}

/**
 * ExpandTreeNode represents a hierarchical node in the userset expansion tree.
 */
final class ExpandTreeNode {
  private ExpandNodeType $type;
  private ?Subject $subject;
  private vec<ExpandTreeNode> $children;

  public function __construct(
    ExpandNodeType $type,
    ?Subject $subject = null,
    vec<ExpandTreeNode> $children = vec[]
  ) {
    $this->type = $type;
    $this->subject = $subject;
    $this->children = $children;
  }

  public function getType(): ExpandNodeType {
    return $this->type;
  }

  public function getSubject(): ?Subject {
    return $this->subject;
  }

  public function getChildren(): vec<ExpandTreeNode> {
    return $this->children;
  }

  public static function leaf(Subject $subject): ExpandTreeNode {
    return new ExpandTreeNode(ExpandNodeType::LEAF, $subject);
  }

  public static function union(vec<ExpandTreeNode> $children): ExpandTreeNode {
    return new ExpandTreeNode(ExpandNodeType::UNION, null, $children);
  }

  public static function intersection(vec<ExpandTreeNode> $children): ExpandTreeNode {
    return new ExpandTreeNode(ExpandNodeType::INTERSECTION, null, $children);
  }
}

/**
 * ExpandEngine inspects and constructs the complete userset resolution tree
 * for debugging, visual inspection, and compliance auditing.
 */
final class ExpandEngine {
  private PolicyRegistry $policies;
  private TupleStore $store;

  public function __construct(PolicyRegistry $policies, TupleStore $store) {
    $this->policies = $policies;
    $this->store = $store;
  }

  public function expand(string $namespace, string $objectId, string $relation): ExpandTreeNode {
    $nsConfig = $this->policies->getNamespace($namespace);
    if ($nsConfig === null) {
      return ExpandTreeNode::union(vec[]);
    }

    $rule = $nsConfig->getRule($relation);
    if ($rule === null) {
      // Direct tuples leaf collection
      $tuples = $this->store->readTuples($namespace, $objectId, $relation);
      $leaves = vec[];
      foreach ($tuples as $t) {
        $leaves[] = ExpandTreeNode::leaf($t->getSubject());
      }
      return ExpandTreeNode::union($leaves);
    }

    return $this->expandRewrite($namespace, $objectId, $rule->getRewrite());
  }

  private function expandRewrite(string $namespace, string $objectId, UsersetRewrite $rewrite): ExpandTreeNode {
    switch ($rewrite->getType()) {
      case RewriteType::THIS:
        $tuples = $this->store->readTuples($namespace, $objectId);
        $leaves = vec[];
        foreach ($tuples as $t) {
          $leaves[] = ExpandTreeNode::leaf($t->getSubject());
        }
        return ExpandTreeNode::union($leaves);

      case RewriteType::COMPUTED_USERSET:
        $cu = $rewrite as ComputedUsersetRewrite;
        return $this->expand($namespace, $objectId, $cu->getRelation());

      case RewriteType::TUPLE_TO_USERSET:
        $ttu = $rewrite as TupleToUsersetRewrite;
        $tuples = $this->store->readTuples($namespace, $objectId, $ttu->getTuplesetRelation());
        $subtrees = vec[];
        foreach ($tuples as $t) {
          $subtrees[] = $this->expand(
            $t->getSubject()->getNamespace(),
            $t->getSubject()->getId(),
            $ttu->getComputedRelation()
          );
        }
        return ExpandTreeNode::union($subtrees);

      case RewriteType::UNION:
        $u = $rewrite as UnionRewrite;
        $children = vec[];
        foreach ($u->getChildren() as $c) {
          $children[] = $this->expandRewrite($namespace, $objectId, $c);
        }
        return ExpandTreeNode::union($children);

      case RewriteType::INTERSECTION:
        $i = $rewrite as IntersectionRewrite;
        $children = vec[];
        foreach ($i->getChildren() as $c) {
          $children[] = $this->expandRewrite($namespace, $objectId, $c);
        }
        return ExpandTreeNode::intersection($children);

      case RewriteType::EXCLUSION:
        $e = $rewrite as ExclusionRewrite;
        return new ExpandTreeNode(
          ExpandNodeType::EXCLUSION,
          null,
          vec[
            $this->expandRewrite($namespace, $objectId, $e->getBase()),
            $this->expandRewrite($namespace, $objectId, $e->getSubtract()),
          ]
        );
    }
  }
}
