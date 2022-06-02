namespace Axon\Tests\Bugs;

use Axon\Storage\WALEntry;
use Axon\Storage\WALOpType;
use Axon\Core\ByteBuffer;

/**
 * Regression Test: Bug #419
 * Description: Torn writes or single-bit flips in the WAL segment caused desync without detection.
 * Resolution: Integrated CRC32 Castagnoli/IEEE checksums at the tail of every WAL binary entry.
 */
final class TestBugWALCorruption {
  public static function run(): void {
    \printf("Running TestBugWALCorruption...\n");

    $valid = new WALEntry(1, 1000, WALOpType::PUT, 'axon_users', 'usr-1', '{"name":"Alice"}');
    $bytes = $valid->serialize();

    // Flip a bit in the payload region
    $corruptedBytes = $bytes;
    $corruptedBytes[20] = \chr(\ord($corruptedBytes[20]) ^ 0xFF);

    $buf = new ByteBuffer($corruptedBytes);
    $deser = WALEntry::deserialize($buf);

    if ($deser->isOk()) {
      throw new \RuntimeException("Corrupted WAL entry should have been rejected by CRC32 check");
    }

    if (!\str_contains($deser->unwrapErr(), 'CRC32 checksum mismatch')) {
      throw new \RuntimeException("Expected CRC32 error message, got: " . $deser->unwrapErr());
    }

    \printf("TestBugWALCorruption passed.\n");
  }
}
