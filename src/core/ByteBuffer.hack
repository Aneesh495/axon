namespace Axon\Core;

/**
 * ByteBuffer provides high-performance binary serialization and deserialization
 * with explicit byte-order controls and bounds checking.
 */
final class ByteBuffer {
  private string $buffer;
  private int $readOffset;
  private int $writeOffset;

  public function __construct(string $initial = '') {
    $this->buffer = $initial;
    $this->readOffset = 0;
    $this->writeOffset = \strlen($initial);
  }

  public static function withCapacity(int $capacity): ByteBuffer {
    return new ByteBuffer('');
  }

  public function length(): int {
    return \strlen($this->buffer);
  }

  public function readableBytes(): int {
    return \max(0, \strlen($this->buffer) - $this->readOffset);
  }

  public function raw(): string {
    return $this->buffer;
  }

  public function getReadOffset(): int {
    return $this->readOffset;
  }

  public function setReadOffset(int $offset): void {
    if ($offset < 0 || $offset > \strlen($this->buffer)) {
      throw new \OutOfBoundsException('Invalid read offset');
    }
    $this->readOffset = $offset;
  }

  public function writeUint8(int $value): void {
    $this->buffer .= \pack('C', $value & 0xFF);
    $this->writeOffset++;
  }

  public function readUint8(): int {
    if ($this->readOffset + 1 > \strlen($this->buffer)) {
      throw new \UnderflowException('Buffer underflow reading uint8');
    }
    $data = \unpack('Cval', \substr($this->buffer, $this->readOffset, 1));
    $this->readOffset += 1;
    return (int)$data['val'];
  }

  public function writeUint16BE(int $value): void {
    $this->buffer .= \pack('n', $value & 0xFFFF);
    $this->writeOffset += 2;
  }

  public function readUint16BE(): int {
    if ($this->readOffset + 2 > \strlen($this->buffer)) {
      throw new \UnderflowException('Buffer underflow reading uint16BE');
    }
    $data = \unpack('nval', \substr($this->buffer, $this->readOffset, 2));
    $this->readOffset += 2;
    return (int)$data['val'];
  }

  public function writeUint32BE(int $value): void {
    $this->buffer .= \pack('N', $value & 0xFFFFFFFF);
    $this->writeOffset += 4;
  }

  public function readUint32BE(): int {
    if ($this->readOffset + 4 > \strlen($this->buffer)) {
      throw new \UnderflowException('Buffer underflow reading uint32BE');
    }
    $data = \unpack('Nval', \substr($this->buffer, $this->readOffset, 4));
    $this->readOffset += 4;
    return (int)$data['val'];
  }

  public function writeInt64BE(int $value): void {
    $this->buffer .= \pack('J', $value);
    $this->writeOffset += 8;
  }

  public function readInt64BE(): int {
    if ($this->readOffset + 8 > \strlen($this->buffer)) {
      throw new \UnderflowException('Buffer underflow reading int64BE');
    }
    $data = \unpack('Jval', \substr($this->buffer, $this->readOffset, 8));
    $this->readOffset += 8;
    return (int)$data['val'];
  }

  public function writeFloat64BE(float $value): void {
    $this->buffer .= \pack('E', $value);
    $this->writeOffset += 8;
  }

  public function readFloat64BE(): float {
    if ($this->readOffset + 8 > \strlen($this->buffer)) {
      throw new \UnderflowException('Buffer underflow reading float64BE');
    }
    $data = \unpack('Eval', \substr($this->buffer, $this->readOffset, 8));
    $this->readOffset += 8;
    return (float)$data['val'];
  }

  public function writeBytes(string $bytes): void {
    $this->buffer .= $bytes;
    $this->writeOffset += \strlen($bytes);
  }

  public function readBytes(int $len): string {
    if ($this->readOffset + $len > \strlen($this->buffer)) {
      throw new \UnderflowException('Buffer underflow reading raw bytes');
    }
    $chunk = \substr($this->buffer, $this->readOffset, $len);
    $this->readOffset += $len;
    return $chunk;
  }

  public function writeStringPrefixed(string $str): void {
    $len = \strlen($str);
    $this->writeUint32BE($len);
    if ($len > 0) {
      $this->writeBytes($str);
    }
  }

  public function readStringPrefixed(): string {
    $len = $this->readUint32BE();
    if ($len === 0) {
      return '';
    }
    return $this->readBytes($len);
  }

  public function clear(): void {
    $this->buffer = '';
    $this->readOffset = 0;
    $this->writeOffset = 0;
  }
}
