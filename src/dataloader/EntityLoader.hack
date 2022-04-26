namespace Axon\DataLoader;

use Axon\Core\AsyncDeferred;

/**
 * EntityLoader batches primary key lookups for a specific entity type.
 */
final class EntityLoader {
  private string $entityName;
  private BatchLoader<string, ?dict<string, mixed>> $loader;

  public function __construct(
    string $entityName,
    (function(vec<string>): dict<string, ?dict<string, mixed>>) $batchFetchFn
  ) {
    $this->entityName = $entityName;
    $this->loader = new BatchLoader<string, ?dict<string, mixed>>($batchFetchFn);
  }

  public function getEntityName(): string {
    return $this->entityName;
  }

  public function load(string $id): AsyncDeferred<?dict<string, mixed>> {
    return $this->loader->load($id, $id);
  }

  public function prime(string $id, ?dict<string, mixed> $data): void {
    $this->loader->prime($id, $data);
  }

  public function clear(string $id): void {
    $this->loader->clear($id);
  }

  public function dispatch(): void {
    $this->loader->dispatch();
  }
}
