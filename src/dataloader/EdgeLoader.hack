namespace Axon\DataLoader;

use Axon\Core\AsyncDeferred;

/**
 * EdgeBatchRequest represents a batched query for an association edge.
 */
final class EdgeBatchRequest {
  private string $sourceId;
  private ?int $limit;
  private ?string $afterCursor;

  public function __construct(string $sourceId, ?int $limit = null, ?string $afterCursor = null) {
    $this->sourceId = $sourceId;
    $this->limit = $limit;
    $this->afterCursor = $afterCursor;
  }

  public function getSourceId(): string {
    return $this->sourceId;
  }

  public function getLimit(): ?int {
    return $this->limit;
  }

  public function getAfterCursor(): ?string {
    return $this->afterCursor;
  }

  public function toKey(): string {
    return \sprintf(
      '%s:%d:%s',
      $this->sourceId,
      $this->limit ?? -1,
      $this->afterCursor ?? 'none'
    );
  }
}

/**
 * EdgeLoader batches relationship edge traversals for high-fanout graph queries.
 */
final class EdgeLoader {
  private string $sourceEntity;
  private string $edgeName;
  private BatchLoader<EdgeBatchRequest, vec<dict<string, mixed>>> $loader;

  public function __construct(
    string $sourceEntity,
    string $edgeName,
    (function(vec<EdgeBatchRequest>): dict<string, vec<dict<string, mixed>>>) $batchFetchFn
  ) {
    $this->sourceEntity = $sourceEntity;
    $this->edgeName = $edgeName;
    $this->loader = new BatchLoader<EdgeBatchRequest, vec<dict<string, mixed>>>($batchFetchFn);
  }

  public function load(
    string $sourceId,
    ?int $limit = null,
    ?string $afterCursor = null
  ): AsyncDeferred<vec<dict<string, mixed>>> {
    $req = new EdgeBatchRequest($sourceId, $limit, $afterCursor);
    return $this->loader->load($req, $req->toKey());
  }

  public function dispatch(): void {
    $this->loader->dispatch();
  }
}
