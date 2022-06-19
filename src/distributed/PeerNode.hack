namespace Axon\Distributed;

/**
 * Peer cluster node states.
 */
enum NodeState: string {
  LEADER = 'LEADER';
  FOLLOWER = 'FOLLOWER';
  CANDIDATE = 'CANDIDATE';
  DEAD = 'DEAD';
}

/**
 * PeerNode represents a participant node in the distributed cluster.
 */
final class PeerNode implements \JsonSerializable {
  private string $id;
  private string $host;
  private int $port;
  private NodeState $state;
  private int $lastHeartbeatMs;

  public function __construct(
    string $id,
    string $host,
    int $port,
    NodeState $state = NodeState::FOLLOWER,
    int $lastHeartbeatMs = 0
  ) {
    $this->id = $id;
    $this->host = $host;
    $this->port = $port;
    $this->state = $state;
    $this->lastHeartbeatMs = $lastHeartbeatMs > 0 ? $lastHeartbeatMs : (int)(\microtime(true) * 1000.0);
  }

  public function getId(): string {
    return $this->id;
  }

  public function getHost(): string {
    return $this->host;
  }

  public function getPort(): int {
    return $this->port;
  }

  public function getState(): NodeState {
    return $this->state;
  }

  public function setState(NodeState $state): void {
    $this->state = $state;
  }

  public function heartbeat(int $nowMs = 0): void {
    $this->lastHeartbeatMs = $nowMs > 0 ? $nowMs : (int)(\microtime(true) * 1000.0);
  }

  public function isAlive(int $timeoutMs = 5000, int $nowMs = 0): bool {
    $current = $nowMs > 0 ? $nowMs : (int)(\microtime(true) * 1000.0);
    return ($current - $this->lastHeartbeatMs) <= $timeoutMs;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'id' => $this->id,
      'host' => $this->host,
      'port' => $this->port,
      'state' => $this->state->value,
      'last_heartbeat' => $this->lastHeartbeatMs,
    ];
  }
}
