namespace Axon\Reactive;

/**
 * SubscriptionClient represents a connected real-time client.
 */
final class SubscriptionClient {
  private string $clientId;
  private int $connectedAt;
  private int $lastHeartbeat;
  private vec<string> $activeSubscriptionIds;

  public function __construct(string $clientId) {
    $now = (int)\time();
    $this->clientId = $clientId;
    $this->connectedAt = $now;
    $this->lastHeartbeat = $now;
    $this->activeSubscriptionIds = vec[];
  }

  public function getClientId(): string {
    return $this->clientId;
  }

  public function recordHeartbeat(): void {
    $this->lastHeartbeat = (int)\time();
  }

  public function addSubscription(string $subId): void {
    $this->activeSubscriptionIds[] = $subId;
  }

  public function getSubscriptions(): vec<string> {
    return $this->activeSubscriptionIds;
  }

  public function isStale(int $timeoutSeconds = 60): bool {
    return ((int)\time() - $this->lastHeartbeat) > $timeoutSeconds;
  }
}

/**
 * SubscriptionHub manages active real-time client sessions and heartbeats.
 */
final class SubscriptionHub {
  private dict<string, SubscriptionClient> $clients;
  private LiveQueryManager $liveQuery;

  public function __construct(LiveQueryManager $liveQuery) {
    $this->clients = dict[];
    $this->liveQuery = $liveQuery;
  }

  public function registerClient(string $clientId): SubscriptionClient {
    $client = new SubscriptionClient($clientId);
    $this->clients[$clientId] = $client;
    return $client;
  }

  public function unregisterClient(string $clientId): void {
    if (\array_key_exists($clientId, $this->clients)) {
      $client = $this->clients[$clientId];
      foreach ($client->getSubscriptions() as $subId) {
        $this->liveQuery->unsubscribe($subId);
      }
      unset($this->clients[$clientId]);
    }
  }

  public function getClientCount(): int {
    return \count($this->clients);
  }
}
