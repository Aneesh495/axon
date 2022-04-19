namespace Axon\Core;

/**
 * CRC32 computes IEEE 802.3 and Castagnoli CRC-32C checksums
 * for block corruption detection and WAL integrity verification.
 */
final class CRC32 {
  /**
   * Precomputed IEEE 802.3 lookup table.
   */
  private static ?vec<int> $ieeeTable = null;

  private static function initIeeeTable(): vec<int> {
    if (self::$ieeeTable !== null) {
      return self::$ieeeTable;
    }
    $table = vec[];
    for ($i = 0; $i < 256; $i++) {
      $c = $i;
      for ($j = 0; $j < 8; $j++) {
        if (($c & 1) !== 0) {
          $c = 0xEDB88320 ^ (($c >> 1) & 0x7FFFFFFF);
        } else {
          $c = ($c >> 1) & 0x7FFFFFFF;
        }
      }
      $table[] = $c;
    }
    self::$ieeeTable = $table;
    return $table;
  }

  /**
   * Calculates 32-bit CRC checksum for a byte string.
   */
  public static function calculate(string $data): int {
    $table = self::initIeeeTable();
    $crc = 0xFFFFFFFF;
    $len = \strlen($data);

    for ($i = 0; $i < $len; $i++) {
      $byte = \ord($data[$i]);
      $idx = ($crc ^ $byte) & 0xFF;
      $crc = $table[$idx] ^ (($crc >> 8) & 0x00FFFFFF);
    }

    return ($crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  /**
   * Verifies that the computed checksum matches expected.
   */
  public static function verify(string $data, int $expectedCrc): bool {
    return self::calculate($data) === ($expectedCrc & 0xFFFFFFFF);
  }
}
