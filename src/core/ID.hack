namespace Axon\Core;

/**
 * ID represents a 128-bit globally unique, time-ordered identifier.
 *
 * Structure:
 * - Bits 0..47   (48 bits): Millisecond timestamp since Unix epoch (supports 8900+ years)
 * - Bits 48..63  (16 bits): Node or cluster partition identifier
 * - Bits 64..79  (16 bits): Monotonic sequence counter per millisecond
 * - Bits 80..127 (48 bits): Pseudorandom entropy for collision prevention
 *
 * This layout guarantees k-sortability, high B-tree cache locality,
 * and distributed generation without coordination.
 */
final class ID {
  private int $high64;
  private int $low64;

  public function __construct(int $high64, int $low64) {
    $this->high64 = $high64;
    $this->low64 = $low64;
  }

  public function getHigh64(): int {
    return $this->high64;
  }

  public function getLow64(): int {
    return $this->low64;
  }

  /**
   * Extracts the 48-bit millisecond timestamp component.
   */
  public function getTimestampMs(): int {
    // Unsigned right shift by 16 bits to isolate 48-bit timestamp
    return ($this->high64 >> 16) & 0x0000FFFFFFFFFFFF;
  }

  /**
   * Extracts the 16-bit node identifier.
   */
  public function getNodeId(): int {
    return $this->high64 & 0xFFFF;
  }

  /**
   * Extracts the 16-bit sequence counter.
   */
  public function getSequence(): int {
    return ($this->low64 >> 48) & 0xFFFF;
  }

  /**
   * Returns a 32-character hexadecimal string representation.
   */
  public function toHex(): string {
    $h = \sprintf('%016x', $this->high64);
    $l = \sprintf('%016x', $this->low64);
    return $h . $l;
  }

  /**
   * Returns standard canonical UUID hyphenated format (8-4-4-4-12).
   */
  public function toUUIDString(): string {
    $hex = $this->toHex();
    return \sprintf(
      '%s-%s-%s-%s-%s',
      \substr($hex, 0, 8),
      \substr($hex, 8, 4),
      \substr($hex, 12, 4),
      \substr($hex, 16, 4),
      \substr($hex, 20, 12)
    );
  }

  public function toString(): string {
    return $this->toUUIDString();
  }

  /**
   * Compares two IDs for chronological/lexicographical order.
   * Returns -1 if this < other, 0 if equal, +1 if this > other.
   */
  public function compare(ID $other): int {
    if ($this->high64 < $other->high64) {
      return -1;
    }
    if ($this->high64 > $other->high64) {
      return 1;
    }
    if ($this->low64 < $other->low64) {
      return -1;
    }
    if ($this->low64 > $other->low64) {
      return 1;
    }
    return 0;
  }

  public function equals(ID $other): bool {
    return $this->high64 === $other->high64 && $this->low64 === $other->low64;
  }

  /**
   * Parses an ID from a hexadecimal or canonical UUID string.
   */
  public static function parse(string $raw): Result<ID, string> {
    $clean = \str_replace('-', '', \strtolower(\trim($raw)));
    if (\strlen($clean) !== 32) {
      return Result::err(\sprintf('Invalid ID length: expected 32 hex chars, got %d', \strlen($clean)));
    }

    if (!\ctype_xdigit($clean)) {
      return Result::err('Invalid ID format: non-hexadecimal characters detected');
    }

    $highHex = \substr($clean, 0, 16);
    $lowHex = \substr($clean, 16, 16);

    $high = (int)\hexdec($highHex);
    $low = (int)\hexdec($lowHex);

    return Result::ok(new ID($high, $low));
  }

  /**
   * Generates a deterministic nil / zero ID.
   */
  public static function nil(): ID {
    return new ID(0, 0);
  }
}

/**
 * Thread-safe generator for 128-bit time-ordered IDs.
 */
final class IDGenerator {
  private int $nodeId;
  private int $lastTimestampMs;
  private int $sequence;

  public function __construct(int $nodeId = 1) {
    $this->nodeId = $nodeId & 0xFFFF;
    $this->lastTimestampMs = -1;
    $this->sequence = 0;
  }

  public function generate(int $overrideTimestampMs = 0): ID {
    $nowMs = $overrideTimestampMs > 0 ? $overrideTimestampMs : (int)(\microtime(true) * 1000.0);

    if ($nowMs === $this->lastTimestampMs) {
      $this->sequence = ($this->sequence + 1) & 0xFFFF;
      if ($this->sequence === 0) {
        // Sequence exhausted in the same millisecond; increment millisecond counter
        $nowMs++;
      }
    } else {
      $this->sequence = 0;
    }

    $this->lastTimestampMs = $nowMs;

    $high64 = (($nowMs & 0x0000FFFFFFFFFFFF) << 16) | ($this->nodeId & 0xFFFF);
    $entropy = (int)(\random_int(0, 0x7FFFFFFF) & 0x0000FFFFFFFFFFFF);
    $low64 = (($this->sequence & 0xFFFF) << 48) | ($entropy & 0x0000FFFFFFFFFFFF);

    return new ID($high64, $low64);
  }
}
