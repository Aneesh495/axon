namespace Axon\Tests\Unit;

use Axon\Storage\WALEntry;
use Axon\Storage\WALOpType;
use Axon\Storage\WriteAheadLog;
use Axon\Core\ByteBuffer;

final class TestWAL {
  public static function run(): void {
    \printf("Running TestWAL...\n");

    $entry = new WALEntry(
      1,
      1609459200000,
      WALOpType::PUT,
      'axon_documents',
      'doc-100',
      '{"title":"System Design"}'
    );

    $bytes = $entry->serialize();
    if (\strlen($bytes) === 0) {
      throw new \RuntimeException("Serialized WAL entry must not be empty");
    }

    $buf = new ByteBuffer($bytes);
    $deser = WALEntry::deserialize($buf);
    if ($deser->isErr()) {
      throw new \RuntimeException("Deserialization failed: " . $deser->unwrapErr());
    }

    $restored = $deser->unwrap();
    if ($restored->getLsn() !== 1 || $restored->getRecordId() !== 'doc-100') {
      throw new \RuntimeException("Restored WAL entry field mismatch");
    }

    // In-memory WAL append and replay
    $wal = new WriteAheadLog();
    $wal->append(WALOpType::PUT, 'axon_documents', 'doc-1', '{"title":"First"}');
    $wal->append(WALOpType::PUT, 'axon_documents', 'doc-2', '{"title":"Second"}');

    if ($wal->getLatestLsn() !== 2) {
      throw new \RuntimeException("WAL latest LSN should be 2");
    }

    $replayed = $wal->replay(1);
    if (\count($replayed) !== 2) {
      throw new \RuntimeException("WAL replay should return 2 entries");
    }

    \printf("TestWAL passed.\n");
  }
}
