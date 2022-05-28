namespace Axon\Tests\Unit;

use Axon\Core\ID;
use Axon\Core\IDGenerator;

final class TestID {
  public static function run(): void {
    \printf("Running TestID...\n");

    $gen = new IDGenerator(42);
    $id1 = $gen->generate(1609459200000); // 2021-01-01 00:00:00 UTC
    $id2 = $gen->generate(1609459200000);

    // Assert monotonicity
    if ($id1->compare($id2) >= 0) {
      throw new \RuntimeException("IDs generated in sequence should be strictly monotonic");
    }

    // Assert node ID
    if ($id1->getNodeId() !== 42) {
      throw new \RuntimeException(\sprintf("Expected nodeId 42, got %d", $id1->getNodeId()));
    }

    // Assert timestamp extraction
    if ($id1->getTimestampMs() !== 1609459200000) {
      throw new \RuntimeException(\sprintf("Expected timestamp 1609459200000, got %d", $id1->getTimestampMs()));
    }

    // Assert round-trip string parsing
    $uuidStr = $id1->toUUIDString();
    $parsed = ID::parse($uuidStr);
    if ($parsed->isErr()) {
      throw new \RuntimeException("Failed to parse valid UUID string: " . $parsed->unwrapErr());
    }
    if (!$parsed->unwrap()->equals($id1)) {
      throw new \RuntimeException("Round-trip parsed ID does not match original");
    }

    // Assert invalid length rejection
    $invalid = ID::parse("too-short");
    if ($invalid->isOk()) {
      throw new \RuntimeException("Parser should reject invalid string length");
    }

    \printf("TestID passed.\n");
  }
}
