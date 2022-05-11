namespace Axon\Storage;

use Axon\Core\Result;

/**
 * MemoryStorage provides a high-throughput, in-memory MVCC storage engine
 * supporting secondary indexing, atomic point updates, and table filtering.
 */
final class MemoryStorage implements StorageEngine {
  private dict<string, dict<string, dict<string, mixed>>> $tables;
  private dict<string, dict<string, SecondaryIndex>> $indexes;

  public function __construct() {
    $this->tables = dict[];
    $this->indexes = dict[];
  }

  public function registerIndex(string $tableName, string $fieldName): void {
    if (!\array_key_exists($tableName, $this->indexes)) {
      $this->indexes[$tableName] = dict[];
    }
    $indexName = \sprintf('idx_%s_%s', $tableName, $fieldName);
    $this->indexes[$tableName][$fieldName] = new SecondaryIndex($indexName, $fieldName);
  }

  public function get(string $tableName, string $id): ?dict<string, mixed> {
    if (!\array_key_exists($tableName, $this->tables)) {
      return null;
    }
    return \array_key_exists($id, $this->tables[$tableName]) ? $this->tables[$tableName][$id] : null;
  }

  public function put(string $tableName, string $id, dict<string, mixed> $record): Result<bool, string> {
    if (!\array_key_exists($tableName, $this->tables)) {
      $this->tables[$tableName] = dict[];
    }

    $existing = $this->get($tableName, $id);
    if ($existing !== null && \array_key_exists($tableName, $this->indexes)) {
      foreach ($this->indexes[$tableName] as $index) {
        $index->removeRecord($id, $existing);
      }
    }

    $this->tables[$tableName][$id] = $record;

    if (\array_key_exists($tableName, $this->indexes)) {
      foreach ($this->indexes[$tableName] as $index) {
        $index->indexRecord($id, $record);
      }
    }

    return Result::ok(true);
  }

  public function delete(string $tableName, string $id): Result<bool, string> {
    if (!\array_key_exists($tableName, $this->tables) || !\array_key_exists($id, $this->tables[$tableName])) {
      return Result::ok(false);
    }

    $old = $this->tables[$tableName][$id];
    unset($this->tables[$tableName][$id]);

    if (\array_key_exists($tableName, $this->indexes)) {
      foreach ($this->indexes[$tableName] as $index) {
        $index->removeRecord($id, $old);
      }
    }

    return Result::ok(true);
  }

  public function scan(
    string $tableName,
    ?dict<string, mixed> $filter = null,
    int $limit = 1000
  ): vec<dict<string, mixed>> {
    if (!\array_key_exists($tableName, $this->tables)) {
      return vec[];
    }

    // Optimization: Check if a secondary index can satisfy the filter
    if ($filter !== null && \array_key_exists($tableName, $this->indexes)) {
      foreach ($filter as $field => $targetVal) {
        if (\array_key_exists($field, $this->indexes[$tableName])) {
          $matchingIds = $this->indexes[$tableName][$field]->lookup((string)$targetVal);
          $matched = vec[];
          foreach ($matchingIds as $matchId) {
            $rec = $this->get($tableName, $matchId);
            if ($rec !== null && $this->matchesFilter($rec, $filter)) {
              $matched[] = $rec;
              if (\count($matched) >= $limit) {
                break;
              }
            }
          }
          return $matched;
        }
      }
    }

    $results = vec[];
    foreach ($this->tables[$tableName] as $record) {
      if ($this->matchesFilter($record, $filter)) {
        $results[] = $record;
        if (\count($results) >= $limit) {
          break;
        }
      }
    }

    return $results;
  }

  private function matchesFilter(dict<string, mixed> $record, ?dict<string, mixed> $filter): bool {
    if ($filter === null) {
      return true;
    }
    foreach ($filter as $k => $v) {
      if (!\array_key_exists($k, $record) || $record[$k] !== $v) {
        return false;
      }
    }
    return true;
  }

  public function count(string $tableName): int {
    return \array_key_exists($tableName, $this->tables) ? \count($this->tables[$tableName]) : 0;
  }

  public function clear(): void {
    $this->tables = dict[];
    foreach ($this->indexes as $tableIndexes) {
      foreach ($tableIndexes as $idx) {
        $idx->clear();
      }
    }
  }
}
