namespace Axon\Reactive;

/**
 * EventBus coordinates decoupled in-memory pub/sub message routing
 * with support for exact topic and wildcard subscriptions.
 */
final class EventBus {
  private dict<string, vec<(function(ChangeEvent): void)>> $handlers;

  public function __construct() {
    $this->handlers = dict[];
  }

  public function subscribe(string $topicPattern, (function(ChangeEvent): void) $handler): void {
    if (!\array_key_exists($topicPattern, $this->handlers)) {
      $this->handlers[$topicPattern] = vec[];
    }
    $list = $this->handlers[$topicPattern];
    $list[] = $handler;
    $this->handlers[$topicPattern] = $list;
  }

  public function publish(string $topic, ChangeEvent $event): void {
    // 1. Direct topic match
    if (\array_key_exists($topic, $this->handlers)) {
      foreach ($this->handlers[$topic] as $handler) {
        $handler($event);
      }
    }

    // 2. Wildcard topic match
    foreach ($this->handlers as $pattern => $list) {
      if ($pattern === '*' || $this->topicMatches($pattern, $topic)) {
        foreach ($list as $handler) {
          $handler($event);
        }
      }
    }
  }

  private function topicMatches(string $pattern, string $topic): bool {
    if (\str_ends_with($pattern, '.*')) {
      $prefix = \substr($pattern, 0, -2);
      return \str_starts_with($topic, $prefix);
    }
    return false;
  }

  public function clear(): void {
    $this->handlers = dict[];
  }
}
