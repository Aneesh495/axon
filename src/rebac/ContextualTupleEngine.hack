namespace Axon\ReBAC;

/**
 * EphemeralTuple wraps a RelationTuple with a deadline timestamp.
 */
final class EphemeralTuple {
  private RelationTuple $tuple;
  private int $expiresAtMs;

  public function __construct(RelationTuple $tuple, int $expiresAtMs) {
    $this->tuple = $tuple;
    $this->expiresAtMs = $expiresAtMs;
  }

  public function getTuple(): RelationTuple {
    return $this->tuple;
  }

  public function isExpired(int $nowMs = 0): bool {
    $current = $nowMs > 0 ? $nowMs : (int)(\microtime(true) * 1000.0);
    return $current >= $this->expiresAtMs;
  }
}

/**
 * ContextualTupleEngine manages request-scoped, temporary, and break-glass relation tuples.
 */
final class ContextualTupleEngine {
  private vec<EphemeralTuple> $ephemeralTuples;

  public function __construct() {
    $this->ephemeralTuples = vec[];
  }

  public function addEphemeralTuple(RelationTuple $tuple, int $ttlSeconds, int $nowMs = 0): void {
    $currentTime = $nowMs > 0 ? $nowMs : (int)(\microtime(true) * 1000.0);
    $expires = $currentTime + ($ttlSeconds * 1000);
    $this->ephemeralTuples[] = new EphemeralTuple($tuple, $expires);
  }

  public function getActiveTuples(int $nowMs = 0): vec<RelationTuple> {
    $active = vec[];
    foreach ($this->ephemeralTuples as $et) {
      if (!$et->isExpired($nowMs)) {
        $active[] = $et->getTuple();
      }
    }
    return $active;
  }

  public function pruneExpired(int $nowMs = 0): void {
    $surviving = vec[];
    foreach ($this->ephemeralTuples as $et) {
      if (!$et->isExpired($nowMs)) {
        $surviving[] = $et;
      }
    }
    $this->ephemeralTuples = $surviving;
  }

  public function clear(): void {
    $this->ephemeralTuples = vec[];
  }
}
