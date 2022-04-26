namespace Axon\DataLoader;

/**
 * DataLoaderRegistry orchestrates all entity and edge loaders for the lifetime
 * of a single client request or query execution context.
 */
final class DataLoaderRegistry {
  private dict<string, EntityLoader> $entityLoaders;
  private dict<string, EdgeLoader> $edgeLoaders;

  public function __construct() {
    $this->entityLoaders = dict[];
    $this->edgeLoaders = dict[];
  }

  public function registerEntityLoader(EntityLoader $loader): void {
    $this->entityLoaders[$loader->getEntityName()] = $loader;
  }

  public function getEntityLoader(string $entityName): ?EntityLoader {
    return \array_key_exists($entityName, $this->entityLoaders)
      ? $this->entityLoaders[$entityName]
      : null;
  }

  public function registerEdgeLoader(string $key, EdgeLoader $loader): void {
    $this->edgeLoaders[$key] = $loader;
  }

  public function getEdgeLoader(string $sourceEntity, string $edgeName): ?EdgeLoader {
    $key = \sprintf('%s.%s', $sourceEntity, $edgeName);
    return \array_key_exists($key, $this->edgeLoaders)
      ? $this->edgeLoaders[$key]
      : null;
  }

  /**
   * Dispatches all enqueued batches across all registered loaders.
   */
  public function dispatchAll(): void {
    foreach ($this->entityLoaders as $loader) {
      $loader->dispatch();
    }
    foreach ($this->edgeLoaders as $loader) {
      $loader->dispatch();
    }
  }
}
