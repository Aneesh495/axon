namespace Axon\Storage;

use Axon\Core\ByteBuffer;
use Axon\Core\CRC32;
use Axon\Core\Result;

/**
 * Log record operation type.
 */
enum WALOpType: int {
  PUT = 1;
  DELETE = 2;
  CHECKPOINT = 3;
}

/**
 * WALEntry represents a durable log sequence record.
 *
 * Wire format:
 * - uint64: LSN (monotonic Log Sequence Number)
 * - uint64: Timestamp (Unix ms)
 * - uint8:  OpType (PUT=1, DELETE=2, CHECKPOINT=3)
 * - uint32-prefixed string: TableName
 * - uint32-prefixed string: RecordId
 * - uint32-prefixed bytes:  Payload JSON
 * - uint32: CRC32 checksum over previous fields
 */
final class WALEntry {
  private int $lsn;
  private int $timestampMs;
  private WALOpType $opType;
  private string $tableName;
  private string $recordId;
  private string $payload;
  private int $checksum;

  public function __construct(
    int $lsn,
    int $timestampMs,
    WALOpType $opType,
    string $tableName,
    string $recordId,
    string $payload = '',
    int $checksum = 0
  ) {
    $this->lsn = $lsn;
    $this->timestampMs = $timestampMs;
    $this->opType = $opType;
    $this->tableName = $tableName;
    $this->recordId = $recordId;
    $this->payload = $payload;
    $this->checksum = $checksum;
  }

  public function getLsn(): int {
    return $this->lsn;
  }

  public function getTimestampMs(): int {
    return $this->timestampMs;
  }

  public function getOpType(): WALOpType {
    return $this->opType;
  }

  public function getTableName(): string {
    return $this->tableName;
  }

  public function getRecordId(): string {
    return $this->recordId;
  }

  public function getPayload(): string {
    return $this->payload;
  }

  public function getChecksum(): int {
    return $this->checksum;
  }

  /**
   * Serializes the entry into a binary byte string including CRC32 checksum.
   */
  public function serialize(): string {
    $buf = new ByteBuffer();
    $buf->writeInt64BE($this->lsn);
    $buf->writeInt64BE($this->timestampMs);
    $buf->writeUint8($this->opType->value);
    $buf->writeStringPrefixed($this->tableName);
    $buf->writeStringPrefixed($this->recordId);
    $buf->writeStringPrefixed($this->payload);

    $computedCrc = CRC32::calculate($buf->raw());
    $buf->writeUint32BE($computedCrc);

    return $buf->raw();
  }

  /**
   * Deserializes and validates a binary WAL entry.
   */
  public static function deserialize(ByteBuffer $buf): Result<WALEntry, string> {
    if ($buf->readableBytes() < 25) {
      return Result::err('Insufficient bytes to read WAL entry header');
    }

    $startOffset = $buf->getReadOffset();

    $lsn = $buf->readInt64BE();
    $ts = $buf->readInt64BE();
    $opRaw = $buf->readUint8();
    $op = WALOpType::tryFrom($opRaw);
    if ($op === null) {
      return Result::err(\sprintf('Unknown WAL operation code: %d', $opRaw));
    }

    $table = $buf->readStringPrefixed();
    $recId = $buf->readStringPrefixed();
    $payload = $buf->readStringPrefixed();

    $endPayloadOffset = $buf->getReadOffset();
    $contentLen = $endPayloadOffset - $startOffset;

    $crcExpected = $buf->readUint32BE();

    $raw = $buf->raw();
    $dataSegment = \substr($raw, $startOffset, $contentLen);
    if (!CRC32::verify($dataSegment, $crcExpected)) {
      return Result::err(\sprintf('CRC32 checksum mismatch for LSN %d', $lsn));
    }

    return Result::ok(new WALEntry($lsn, $ts, $op, $table, $recId, $payload, $crcExpected));
  }
}
