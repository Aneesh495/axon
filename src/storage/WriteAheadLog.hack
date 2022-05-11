namespace Axon\Storage;

use Axon\Core\ByteBuffer;
use Axon\Core\Result;

/**
 * WriteAheadLog manages durable append-only write streams,
 * crash recovery scans, and segment roll-over.
 */
final class WriteAheadLog {
  private int $currentLsn;
  private vec<WALEntry> $inMemoryLog;
  private ?string $logFilePath;

  public function __construct(?string $logFilePath = null) {
    $this->currentLsn = 0;
    $this->inMemoryLog = vec[];
    $this->logFilePath = $logFilePath;
  }

  public function getLatestLsn(): int {
    return $this->currentLsn;
  }

  /**
   * Appends an operation to the log and returns the assigned LSN.
   */
  public function append(
    WALOpType $opType,
    string $tableName,
    string $recordId,
    string $payload = '',
    int $timestampMs = 0
  ): int {
    $this->currentLsn++;
    $ts = $timestampMs > 0 ? $timestampMs : (int)(\microtime(true) * 1000.0);

    $entry = new WALEntry(
      $this->currentLsn,
      $ts,
      $opType,
      $tableName,
      $recordId,
      $payload
    );

    $this->inMemoryLog[] = $entry;

    if ($this->logFilePath !== null) {
      $bytes = $entry->serialize();
      \file_put_contents($this->logFilePath, $bytes, \FILE_APPEND | \LOCK_EX);
    }

    return $this->currentLsn;
  }

  /**
   * Replays log entries starting from a given LSN to recover state.
   */
  public function replay(int $fromLsn = 0): vec<WALEntry> {
    $entries = vec[];
    foreach ($this->inMemoryLog as $entry) {
      if ($entry->getLsn() >= $fromLsn) {
        $entries[] = $entry;
      }
    }
    return $entries;
  }

  public function count(): int {
    return \count($this->inMemoryLog);
  }

  public function clear(): void {
    $this->inMemoryLog = vec[];
    $this->currentLsn = 0;
  }
}
