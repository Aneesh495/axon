namespace Axon\Tests\Unit;

use Axon\Core\ByteBuffer;

final class TestByteBuffer {
  public static function run(): void {
    \printf("Running TestByteBuffer...\n");

    $buf = new ByteBuffer();
    $buf->writeUint8(255);
    $buf->writeUint16BE(65530);
    $buf->writeUint32BE(305419896); // 0x12345678
    $buf->writeInt64BE(987654321012345);
    $buf->writeStringPrefixed("Axon Federated Engine");

    if ($buf->readUint8() !== 255) {
      throw new \RuntimeException("Uint8 mismatch");
    }
    if ($buf->readUint16BE() !== 65530) {
      throw new \RuntimeException("Uint16BE mismatch");
    }
    if ($buf->readUint32BE() !== 305419896) {
      throw new \RuntimeException("Uint32BE mismatch");
    }
    if ($buf->readInt64BE() !== 987654321012345) {
      throw new \RuntimeException("Int64BE mismatch");
    }
    if ($buf->readStringPrefixed() !== "Axon Federated Engine") {
      throw new \RuntimeException("String prefix mismatch");
    }

    if ($buf->readableBytes() !== 0) {
      throw new \RuntimeException("Buffer should have 0 readable bytes remaining");
    }

    \printf("TestByteBuffer passed.\n");
  }
}
