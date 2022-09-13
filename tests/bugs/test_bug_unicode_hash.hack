namespace Axon\Tests\Bugs;

use Axon\Core\CRC32;
use Axon\Storage\BloomFilter;

/**
 * Regression Test: Bug #502
 * Description: Multibyte UTF-8 strings caused buffer slicing index offsets to misalign.
 * Resolution: Explicit byte-length measuring using strlen over byte sequences.
 */
final class TestBugUnicodeHash {
  public static function run(): void {
    \printf("Running TestBugUnicodeHash...\n");

    $unicodeKey = "entity:user:🚀_quantum_node_42_日本語_テスト";
    $crc = CRC32::calculate($unicodeKey);

    if ($crc === 0) {
      throw new \RuntimeException("CRC32 calculation on unicode key returned 0");
    }

    $filter = new BloomFilter(100, 0.01);
    $filter->add($unicodeKey);

    if (!$filter->mightContain($unicodeKey)) {
      throw new \RuntimeException("Bloom filter failed to recognize multibyte unicode key");
    }

    \printf("TestBugUnicodeHash passed.\n");
  }
}
