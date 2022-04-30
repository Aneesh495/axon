namespace Axon\Cache;

/**
 * InvalidationMessage carries entity or key invalidation events across nodes.
 */
final class InvalidationMessage {
  private string $topic;
  private string $targetKey;
  private int $timestamp;
  private string $originNode;

  public function __construct(
    string $topic,
    string $targetKey,
    int $timestamp,
    string $originNode = 'node-1'
  ) {
    $this->topic = $topic;
    $this->targetKey = $targetKey;
    $this->timestamp = $timestamp;
    $this->originNode = $originNode;
  }

  public function getTopic(): string {
    return $this->topic;
  }

  public function getTargetKey(): string {
    return $this->targetKey;
  }

  public function getTimestamp(): int {
    return $this->timestamp;
  }

  public function getOriginNode(): string {
    return $this->originNode;
  }
}

/**
 * InvalidationBus dispatches cache invalidation notices to registered subscribers.
 */
final class InvalidationBus {
  private dict<string, vec<(function(InvalidationMessage): void)>> $subscribers;

  public function __construct() {
    $this->subscribers = dict[];
  }

  public function subscribe(string $topic, (function(InvalidationMessage): void) $handler): void {
    if (!\array_key_exists($topic, $this->subscribers)) {
      $this->subscribers[$topic] = vec[];
    }
    $list = $this->subscribers[$topic];
    $list[] = $handler;
    $this->subscribers[$topic] = $list;
  }

  public function publish(InvalidationMessage $msg): void {
    $topic = $msg->getTopic();
    if (\array_key_exists($topic, $this->subscribers)) {
      foreach ($this->subscribers[$topic] as $handler) {
        $handler($msg);
      }
    }
    // Also notify wildcard subscribers
    if (\array_key_exists('*', $this->subscribers)) {
      foreach ($this->subscribers['*'] as $handler) {
        $handler($msg);
      }
    }
  }
}
