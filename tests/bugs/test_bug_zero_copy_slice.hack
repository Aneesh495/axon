namespace Axon\Tests\Bugs;

use Axon\Core\ByteBuffer;

/**
 * Regression Test: Bug #611
 * Description: Reading past the end of ByteBuffer produced empty string without raising underflow exception.
 * Resolution: Strict boundary checks asserting readOffset + len <= bufferLength.
 */
final class TestBugZeroCopySlice {
  public static function run(): void {
    \printf("Running TestBugZeroCopySlice...\n");

    $buf = new ByteBuffer("short");
    $caught = false;

    try {
      // Attempt to read 10 bytes from a 5-byte buffer
      $buf->readBytes(10);
    } catch (\UnderflowException $e) {
      $caught = true;
    }

    if (!$caught) {
      throw new \RuntimeException("ByteBuffer should have thrown UnderflowException when reading past buffer bounds");
    }

    \printf("TestBugZeroCopySlice passed.\n");
  }
}
