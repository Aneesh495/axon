namespace Axon\Tests\Unit;

use Axon\Core\CRC32;

final class TestCRC32 {
  public static function run(): void {
    \printf("Running TestCRC32...\n");

    // Standard test vector "123456789" -> 0xCBF43926
    $input = "123456789";
    $checksum = CRC32::calculate($input);
    $expected = 0xCBF43926;

    if ($checksum !== $expected) {
      throw new \RuntimeException(\sprintf("CRC32 mismatch: expected 0x%08X, got 0x%08X", $expected, $checksum));
    }

    if (!CRC32::verify($input, $expected)) {
      throw new \RuntimeException("CRC32 verify failed for valid input");
    }

    if (CRC32::verify("corrupted_payload", $expected)) {
      throw new \RuntimeException("CRC32 verify succeeded on corrupted payload");
    }

    \printf("TestCRC32 passed.\n");
  }
}
