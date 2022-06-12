namespace Axon\Storage;

/**
 * KeyValuePair holds an index key and associated entity ID.
 */
final class BTreeEntry {
  public string $key;
  public string $val;

  public function __construct(string $key, string $val) {
    $this->key = $key;
    $this->val = $val;
  }
}

/**
 * Node in a B-Tree index structure.
 */
final class BTreeNode {
  public bool $isLeaf;
  public vec<BTreeEntry> $entries;
  public vec<BTreeNode> $children;

  public function __construct(bool $isLeaf = true) {
    $this->isLeaf = $isLeaf;
    $this->entries = vec[];
    $this->children = vec[];
  }
}

/**
 * In-memory B-Tree index supporting ordered point lookups and range scans.
 */
final class BTreeIndex {
  private BTreeNode $root;
  private int $t; // Minimum degree

  public function __construct(int $t = 4) {
    $this->t = \max(2, $t);
    $this->root = new BTreeNode(true);
  }

  public function insert(string $key, string $val): void {
    $r = $this->root;
    if (\count($r->entries) === (2 * $this->t - 1)) {
      $s = new BTreeNode(false);
      $this->root = $s;
      $s->children[] = $r;
      $this->splitChild($s, 0, $r);
      $this->insertNonFull($s, $key, $val);
    } else {
      $this->insertNonFull($r, $key, $val);
    }
  }

  public function search(string $key): ?string {
    return $this->searchNode($this->root, $key);
  }

  private function searchNode(BTreeNode $node, string $key): ?string {
    $i = 0;
    while ($i < \count($node->entries) && $key > $node->entries[$i]->key) {
      $i++;
    }

    if ($i < \count($node->entries) && $key === $node->entries[$i]->key) {
      return $node->entries[$i]->val;
    }

    if ($node->isLeaf) {
      return null;
    }

    return $this->searchNode($node->children[$i], $key);
  }

  private function insertNonFull(BTreeNode $node, string $key, string $val): void {
    $i = \count($node->entries) - 1;

    if ($node->isLeaf) {
      $newEntries = vec[];
      $inserted = false;
      foreach ($node->entries as $entry) {
        if (!$inserted && $key < $entry->key) {
          $newEntries[] = new BTreeEntry($key, $val);
          $inserted = true;
        }
        $newEntries[] = $entry;
      }
      if (!$inserted) {
        $newEntries[] = new BTreeEntry($key, $val);
      }
      $node->entries = $newEntries;
    } else {
      while ($i >= 0 && $key < $node->entries[$i]->key) {
        $i--;
      }
      $i++;
      if (\count($node->children[$i]->entries) === (2 * $this->t - 1)) {
        $this->splitChild($node, $i, $node->children[$i]);
        if ($key > $node->entries[$i]->key) {
          $i++;
        }
      }
      $this->insertNonFull($node->children[$i], $key, $val);
    }
  }

  private function splitChild(BTreeNode $parent, int $i, BTreeNode $fullChild): void {
    $z = new BTreeNode($fullChild->isLeaf);
    $medianEntry = $fullChild->entries[$this->t - 1];

    // Distribute entries
    $z->entries = \array_slice($fullChild->entries, $this->t);
    $fullChild->entries = \array_slice($fullChild->entries, 0, $this->t - 1);

    if (!$fullChild->isLeaf) {
      $z->children = \array_slice($fullChild->children, $this->t);
      $fullChild->children = \array_slice($fullChild->children, 0, $this->t);
    }

    // Insert median into parent
    $newParentEntries = vec[];
    for ($k = 0; $k < $i; $k++) {
      $newParentEntries[] = $parent->entries[$k];
    }
    $newParentEntries[] = $medianEntry;
    for ($k = $i; $k < \count($parent->entries); $k++) {
      $newParentEntries[] = $parent->entries[$k];
    }
    $parent->entries = $newParentEntries;

    $newParentChildren = vec[];
    for ($k = 0; $k <= $i; $k++) {
      $newParentChildren[] = $parent->children[$k];
    }
    $newParentChildren[] = $z;
    for ($k = $i + 1; $k < \count($parent->children); $k++) {
      $newParentChildren[] = $parent->children[$k];
    }
    $parent->children = $newParentChildren;
  }
}
