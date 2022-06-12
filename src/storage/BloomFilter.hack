namespace Axon\Storage;

use Axon\Core\CRC32;

/**
 * BloomFilter provides a memory-efficient probabilistic set membership filter
 * preventing unnecessary storage engine scans for non-existent keys.
 */
final class BloomFilter {
  private int $sizeBits;
  private int $numHashFunctions;
  private vec<bool> $bitset;

  public function __construct(int $expectedElements = 10000, float $falsePositiveRate = 0.01) {
    // m = - (n * ln(p)) / (ln(2)^2)
    $m = (int)(-(float)$expectedElements * \log($falsePositiveRate) / (\pow(\log(2), 2)));
    $this->sizeBits = \max(64, $m);

    // k = (m / n) * ln(2)
    $k = (int)(((float)$this->sizeBits / (float)$expectedElements) * \log(2));
    $this->numHashFunctions = \max(1, $k);

    $this->bitset = vec[];
    for ($i = 0; $i < $this->sizeBits; $i++) {
      $this->bitset[] = false;
    }
  }

  public function add(string $key): void {
    $hashes = $this->getHashes($key);
    foreach ($hashes as $h) {
      $idx = $h % $this->sizeBits;
      $this->bitset[$idx] = true;
    }
  }

  public function mightContain(string $key): bool {
    $hashes = $this->getHashes($key);
    foreach ($hashes as $h) {
      $idx = $h % $this->sizeBits;
      if (!$this->bitset[$idx]) {
        return false;
      }
    }
    return true;
  }

  public function getSizeBits(): int {
    return $this->sizeBits;
  }

  public function getNumHashFunctions(): int {
    return $this->numHashFunctions;
  }

  private function getHashes(string $key): vec<int> {
    $hashes = vec[];
    $h1 = CRC32::calculate($key);
    $h2 = CRC32::calculate($key . '_salt_v2');

    // Kirsch-Mitzenmacher optimization: g_i(x) = h1(x) + i * h2(x)
    for ($i = 0; $i < $this->numHashFunctions; $i++) {
      $combined = ($h1 + ($i * $h2)) & 0x7FFFFFFF;
      $hashes[] = $combined;
    }

    return $hashes;
  }

  public function clear(): void {
    for ($i = 0; $i < $this->sizeBits; $i++) {
      $this->bitset[$i] = false;
    }
  }
}
