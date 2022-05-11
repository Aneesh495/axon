namespace Axon\Storage;

use Axon\Core\Result;

/**
 * StorageEngine defines the common CRUD and scanning interface for underlying state engines.
 */
interface StorageEngine {
  public function get(string $tableName, string $id): ?dict<string, mixed>;

  public function put(string $tableName, string $id, dict<string, mixed> $record): Result<bool, string>;

  public function delete(string $tableName, string $id): Result<bool, string>;

  public function scan(
    string $tableName,
    ?dict<string, mixed> $filter = null,
    int $limit = 1000
  ): vec<dict<string, mixed>>;

  public function count(string $tableName): int;

  public function clear(): void;
}
