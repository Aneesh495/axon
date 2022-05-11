namespace Axon\Storage;

/**
 * SecondaryIndex maintains an inverted mapping from indexed field values to entity IDs.
 */
final class SecondaryIndex {
  private string $name;
  private string $fieldName;
  private dict<string, keyset<string>> $index;

  public function __construct(string $name, string $fieldName) {
    $this->name = $name;
    $this->fieldName = $fieldName;
    $this->index = dict[];
  }

  public function getName(): string {
    return $this->name;
  }

  public function getFieldName(): string {
    return $this->fieldName;
  }

  public function indexRecord(string $id, dict<string, mixed> $record): void {
    if (!\array_key_exists($this->fieldName, $record) || $record[$this->fieldName] === null) {
      return;
    }

    $valKey = (string)$record[$this->fieldName];
    if (!\array_key_exists($valKey, $this->index)) {
      $this->index[$valKey] = keyset[];
    }
    $set = $this->index[$valKey];
    $set[] = $id;
    $this->index[$valKey] = $set;
  }

  public function removeRecord(string $id, dict<string, mixed> $oldRecord): void {
    if (!\array_key_exists($this->fieldName, $oldRecord) || $oldRecord[$this->fieldName] === null) {
      return;
    }

    $valKey = (string)$oldRecord[$this->fieldName];
    if (\array_key_exists($valKey, $this->index)) {
      $filtered = keyset[];
      foreach ($this->index[$valKey] as $existingId) {
        if ($existingId !== $id) {
          $filtered[] = $existingId;
        }
      }
      if (\count($filtered) === 0) {
        unset($this->index[$valKey]);
      } else {
        $this->index[$valKey] = $filtered;
      }
    }
  }

  public function lookup(string $value): vec<string> {
    if (\array_key_exists($value, $this->index)) {
      return vec($this->index[$value]);
    }
    return vec[];
  }

  public function clear(): void {
    $this->index = dict[];
  }
}
