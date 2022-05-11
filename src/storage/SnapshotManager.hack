namespace Axon\Storage;

use Axon\Core\Result;

/**
 * SnapshotManager captures point-in-time state images of storage tables,
 * enabling fast warm-starts and log compaction.
 */
final class SnapshotManager {
  private StorageEngine $storage;
  private WriteAheadLog $wal;

  public function __construct(StorageEngine $storage, WriteAheadLog $wal) {
    $this->storage = $storage;
    $this->wal = $wal;
  }

  /**
   * Creates a serialized snapshot dictionary capturing current tables and LSN.
   */
  public function createSnapshot(vec<string> $tableNames): dict<string, mixed> {
    $snapshotLsn = $this->wal->getLatestLsn();
    $tablesDump = dict[];

    foreach ($tableNames as $table) {
      $records = $this->storage->scan($table, null, 100000);
      $tablesDump[$table] = $records;
    }

    return dict[
      'lsn' => $snapshotLsn,
      'timestamp' => (int)\time(),
      'tables' => $tablesDump,
    ];
  }

  /**
   * Restores state from a snapshot and replays subsequent WAL records.
   */
  public function restoreSnapshot(dict<string, mixed> $snapshot): Result<int, string> {
    if (!\array_key_exists('lsn', $snapshot) || !\array_key_exists('tables', $snapshot)) {
      return Result::err('Invalid snapshot format: missing lsn or tables');
    }

    $snapshotLsn = (int)$snapshot['lsn'];
    $tables = $snapshot['tables'] as dict<string, vec<dict<string, mixed>>>;

    $this->storage->clear();

    foreach ($tables as $table => $records) {
      foreach ($records as $record) {
        $id = (string)($record['id'] ?? '');
        if ($id !== '') {
          $this->storage->put($table, $id, $record);
        }
      }
    }

    // Replay WAL entries strictly after the snapshot LSN
    $remainingEntries = $this->wal->replay($snapshotLsn + 1);
    foreach ($remainingEntries as $entry) {
      $table = $entry->getTableName();
      $recId = $entry->getRecordId();

      if ($entry->getOpType() === WALOpType::PUT) {
        $decoded = \json_decode($entry->getPayload(), true);
        if (\is_dict($decoded)) {
          $this->storage->put($table, $recId, $decoded);
        }
      } else if ($entry->getOpType() === WALOpType::DELETE) {
        $this->storage->delete($table, $recId);
      }
    }

    return Result::ok($this->wal->getLatestLsn());
  }
}
