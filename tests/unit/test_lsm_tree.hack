namespace Axon\Tests\Unit;

use Axon\Storage\LSMTree;

final class TestLSMTree {
  public static function run(): void {
    \printf("Running TestLSMTree...\n");

    $lsm = new LSMTree(3); // Flushes every 3 entries

    $lsm->put('key1', 'val1');
    $lsm->put('key2', 'val2');
    $lsm->put('key3', 'val3'); // Triggers flush to SSTable 1

    if ($lsm->getSSTableCount() !== 1) {
      throw new \RuntimeException("LSM tree should have flushed 1 SSTable");
    }

    if ($lsm->get('key1') !== 'val1' || $lsm->get('key2') !== 'val2') {
      throw new \RuntimeException("Failed to read keys from flushed SSTable");
    }

    // Insert more and overwrite key1
    $lsm->put('key1', 'val1_updated');
    $lsm->put('key4', 'val4');
    $lsm->put('key5', 'val5'); // Triggers flush to SSTable 2

    if ($lsm->getSSTableCount() !== 2) {
      throw new \RuntimeException("LSM tree should have flushed 2 SSTables");
    }

    if ($lsm->get('key1') !== 'val1_updated') {
      throw new \RuntimeException("LSM tree should return updated value for key1");
    }

    // Run compaction
    $lsm->compact();
    if ($lsm->getSSTableCount() !== 1) {
      throw new \RuntimeException("LSM compaction should consolidate SSTables to 1");
    }
    if ($lsm->get('key1') !== 'val1_updated' || $lsm->get('key4') !== 'val4') {
      throw new \RuntimeException("Data integrity lost after compaction");
    }

    \printf("TestLSMTree passed.\n");
  }
}
