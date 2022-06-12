namespace Axon\Storage;

/**
 * SSTable represents an immutable sorted string table with an attached Bloom filter.
 */
final class SSTable {
  private dict<string, ?string> $data;
  private BloomFilter $bloom;

  public function __construct(dict<string, ?string> $sortedData) {
    $this->data = $sortedData;
    $this->bloom = new BloomFilter(\max(10, \count($sortedData)), 0.01);
    foreach ($sortedData as $k => $_) {
      $this->bloom->add($k);
    }
  }

  public function get(string $key): ?string {
    if (!$this->bloom->mightContain($key)) {
      return null;
    }
    return \array_key_exists($key, $this->data) ? $this->data[$key] : null;
  }

  public function hasKey(string $key): bool {
    if (!$this->bloom->mightContain($key)) {
      return false;
    }
    return \array_key_exists($key, $this->data);
  }

  public function getData(): dict<string, ?string> {
    return $this->data;
  }
}

/**
 * Log-Structured Merge (LSM) Tree engine.
 * Combines an active MemTable with flushed immutable SSTable levels and compaction.
 */
final class LSMTree {
  private dict<string, ?string> $memtable;
  private int $memtableThreshold;
  private vec<SSTable> $sstables;

  public function __construct(int $memtableThreshold = 100) {
    $this->memtable = dict[];
    $this->memtableThreshold = $memtableThreshold;
    $this->sstables = vec[];
  }

  public function put(string $key, string $val): void {
    $this->memtable[$key] = $val;
    if (\count($this->memtable) >= $this->memtableThreshold) {
      $this->flush();
    }
  }

  public function delete(string $key): void {
    // Tombstone deletion
    $this->memtable[$key] = null;
    if (\count($this->memtable) >= $this->memtableThreshold) {
      $this->flush();
    }
  }

  public function get(string $key): ?string {
    // 1. Check active MemTable
    if (\array_key_exists($key, $this->memtable)) {
      return $this->memtable[$key];
    }

    // 2. Search SSTables from newest to oldest
    $count = \count($this->sstables);
    for ($i = $count - 1; $i >= 0; $i--) {
      $sstable = $this->sstables[$i];
      if ($sstable->hasKey($key)) {
        return $sstable->get($key);
      }
    }

    return null;
  }

  public function flush(): void {
    if (\count($this->memtable) === 0) {
      return;
    }

    $sortedKeys = vec(\array_keys($this->memtable));
    // Sort keys alphabetically
    \sort(&$sortedKeys);

    $sortedData = dict[];
    foreach ($sortedKeys as $k) {
      $sortedData[$k] = $this->memtable[$k];
    }

    $this->sstables[] = new SSTable($sortedData);
    $this->memtable = dict[];
  }

  public function compact(): void {
    if (\count($this->sstables) < 2) {
      return;
    }

    $merged = dict[];
    foreach ($this->sstables as $sstable) {
      foreach ($sstable->getData() as $k => $v) {
        if ($v === null) {
          unset($merged[$k]);
        } else {
          $merged[$k] = $v;
        }
      }
    }

    $sortedKeys = vec(\array_keys($merged));
    \sort(&$sortedKeys);

    $sortedData = dict[];
    foreach ($sortedKeys as $k) {
      $sortedData[$k] = $merged[$k];
    }

    $this->sstables = vec[new SSTable($sortedData)];
  }

  public function getSSTableCount(): int {
    return \count($this->sstables);
  }
}
