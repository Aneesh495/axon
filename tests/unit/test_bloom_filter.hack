namespace Axon\Tests\Unit;

use Axon\Storage\BloomFilter;

final class TestBloomFilter {
  public static function run(): void {
    \printf("Running TestBloomFilter...\n");

    $filter = new BloomFilter(1000, 0.01);

    $filter->add("user:alice");
    $filter->add("user:bob");
    $filter->add("user:charlie");

    if (!$filter->mightContain("user:alice")) {
      throw new \RuntimeException("Bloom filter false negative on alice");
    }
    if (!$filter->mightContain("user:bob")) {
      throw new \RuntimeException("Bloom filter false negative on bob");
    }
    if (!$filter->mightContain("user:charlie")) {
      throw new \RuntimeException("Bloom filter false negative on charlie");
    }

    // High probability true negative
    if ($filter->mightContain("user:definitely_not_present_xyz_12345")) {
      // Small possibility of false positive, but with 3 elements in 1000-sized filter, probability < 1e-6
      throw new \RuntimeException("Unexpected false positive on empty key");
    }

    \printf("TestBloomFilter passed.\n");
  }
}
