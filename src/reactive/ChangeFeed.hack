namespace Axon\Reactive;

/**
 * Mutation operation type in a change data capture stream.
 */
enum ChangeOp: string {
  INSERT = 'INSERT';
  UPDATE = 'UPDATE';
  DELETE = 'DELETE';
}

/**
 * ChangeEvent represents an immutable record of an entity mutation.
 */
final class ChangeEvent implements \JsonSerializable {
  private string $id;
  private string $entityName;
  private ChangeOp $operation;
  private ?dict<string, mixed> $oldRecord;
  private ?dict<string, mixed> $newRecord;
  private int $lsn;
  private int $timestamp;
  private ?string $actorId;

  public function __construct(
    string $id,
    string $entityName,
    ChangeOp $operation,
    ?dict<string, mixed> $oldRecord,
    ?dict<string, mixed> $newRecord,
    int $lsn,
    int $timestamp,
    ?string $actorId = null
  ) {
    $this->id = $id;
    $this->entityName = $entityName;
    $this->operation = $operation;
    $this->oldRecord = $oldRecord;
    $this->newRecord = $newRecord;
    $this->lsn = $lsn;
    $this->timestamp = $timestamp;
    $this->actorId = $actorId;
  }

  public function getId(): string {
    return $this->id;
  }

  public function getEntityName(): string {
    return $this->entityName;
  }

  public function getOperation(): ChangeOp {
    return $this->operation;
  }

  public function getOldRecord(): ?dict<string, mixed> {
    return $this->oldRecord;
  }

  public function getNewRecord(): ?dict<string, mixed> {
    return $this->newRecord;
  }

  public function getLsn(): int {
    return $this->lsn;
  }

  public function getTimestamp(): int {
    return $this->timestamp;
  }

  public function getActorId(): ?string {
    return $this->actorId;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'id' => $this->id,
      'entity' => $this->entityName,
      'op' => $this->operation->value,
      'old' => $this->oldRecord,
      'new' => $this->newRecord,
      'lsn' => $this->lsn,
      'timestamp' => $this->timestamp,
      'actor' => $this->actorId,
    ];
  }
}
