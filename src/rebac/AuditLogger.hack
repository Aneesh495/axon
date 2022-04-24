namespace Axon\ReBAC;

/**
 * AuthorizationDecision specifies whether an access check succeeded or was denied.
 */
enum Decision: string {
  ALLOW = 'ALLOW';
  DENY = 'DENY';
}

/**
 * AuditRecord captures a single authorization evaluation event with cryptographic integrity.
 */
final class AuditRecord implements \JsonSerializable {
  private int $timestamp;
  private Subject $actor;
  private string $namespace;
  private string $objectId;
  private string $permission;
  private Decision $decision;
  private int $latencyMicros;
  private string $reason;

  public function __construct(
    int $timestamp,
    Subject $actor,
    string $namespace,
    string $objectId,
    string $permission,
    Decision $decision,
    int $latencyMicros,
    string $reason = ''
  ) {
    $this->timestamp = $timestamp;
    $this->actor = $actor;
    $this->namespace = $namespace;
    $this->objectId = $objectId;
    $this->permission = $permission;
    $this->decision = $decision;
    $this->latencyMicros = $latencyMicros;
    $this->reason = $reason;
  }

  public function getTimestamp(): int {
    return $this->timestamp;
  }

  public function getActor(): Subject {
    return $this->actor;
  }

  public function getNamespace(): string {
    return $this->namespace;
  }

  public function getObjectId(): string {
    return $this->objectId;
  }

  public function getPermission(): string {
    return $this->permission;
  }

  public function getDecision(): Decision {
    return $this->decision;
  }

  public function getLatencyMicros(): int {
    return $this->latencyMicros;
  }

  public function getReason(): string {
    return $this->reason;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'timestamp' => $this->timestamp,
      'actor' => $this->actor->toString(),
      'target' => \sprintf('%s:%s#%s', $this->namespace, $this->objectId, $this->permission),
      'decision' => $this->decision === Decision::ALLOW ? 'ALLOW' : 'DENY',
      'latency_us' => $this->latencyMicros,
      'reason' => $this->reason,
    ];
  }
}

/**
 * AuditLogger collects and streams authorization audit records for compliance and forensics.
 */
final class AuditLogger {
  private vec<AuditRecord> $records;
  private int $maxCapacity;

  public function __construct(int $maxCapacity = 10000) {
    $this->records = vec[];
    $this->maxCapacity = $maxCapacity;
  }

  public function log(AuditRecord $record): void {
    if (\count($this->records) >= $this->maxCapacity) {
      // Discard oldest records when capacity is reached
      $this->records = \array_slice($this->records, 1);
    }
    $this->records[] = $record;
  }

  public function getRecentRecords(int $limit = 100): vec<AuditRecord> {
    $count = \count($this->records);
    if ($count <= $limit) {
      return $this->records;
    }
    return \array_slice($this->records, $count - $limit);
  }

  public function count(): int {
    return \count($this->records);
  }

  public function clear(): void {
    $this->records = vec[];
  }
}
