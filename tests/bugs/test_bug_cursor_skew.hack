namespace Axon\Tests\Bugs;

use Axon\Query\CursorCodec;

/**
 * Regression Test: Bug #307
 * Description: Malformed, corrupt, or non-base64 cursor tokens caused unhandled fatal exceptions.
 * Resolution: Safe base64 decoding and prefix verification in CursorCodec::decode.
 */
final class TestBugCursorSkew {
  public static function run(): void {
    \printf("Running TestBugCursorSkew...\n");

    // Null or empty string should decode safely to offset 0
    if (CursorCodec::decode(null) !== 0) {
      throw new \RuntimeException("Null cursor should decode to offset 0");
    }
    if (CursorCodec::decode('') !== 0) {
      throw new \RuntimeException("Empty cursor should decode to offset 0");
    }

    // Malformed base64
    if (CursorCodec::decode('%%%invalid-base64%%%') !== 0) {
      throw new \RuntimeException("Invalid base64 should safely decode to 0");
    }

    // Valid cursor
    $encoded = CursorCodec::encode(42);
    if (CursorCodec::decode($encoded) !== 42) {
      throw new \RuntimeException("Valid cursor did not decode to 42");
    }

    \printf("TestBugCursorSkew passed.\n");
  }
}
