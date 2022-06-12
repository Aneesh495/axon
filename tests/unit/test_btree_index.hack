namespace Axon\Tests\Unit;

use Axon\Storage\BTreeIndex;

final class TestBTreeIndex {
  public static function run(): void {
    \printf("Running TestBTreeIndex...\n");

    $btree = new BTreeIndex(3);

    $items = dict[
      'alpha' => 'val_a',
      'beta' => 'val_b',
      'gamma' => 'val_c',
      'delta' => 'val_d',
      'epsilon' => 'val_e',
      'zeta' => 'val_z',
      'eta' => 'val_eta',
    ];

    foreach ($items as $k => $v) {
      $btree->insert($k, $v);
    }

    foreach ($items as $k => $v) {
      $found = $btree->search($k);
      if ($found !== $v) {
        throw new \RuntimeException(\sprintf("BTree lookup failed for key %s: expected %s, got %s", $k, $v, $found ?? 'null'));
      }
    }

    if ($btree->search('nonexistent') !== null) {
      throw new \RuntimeException("BTree search for nonexistent key should return null");
    }

    \printf("TestBTreeIndex passed.\n");
  }
}
