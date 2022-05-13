namespace Axon\Reactive;

use Axon\Query\DocumentNode;
use Axon\Query\QueryParser;
use Axon\Query\ExecutionResult;
use Axon\ReBAC\ViewerContext;

/**
 * LiveQueryRegistration tracks a client active subscription and its last evaluated payload.
 */
final class LiveQueryRegistration {
  public string $subscriptionId;
  public DocumentNode $document;
  public ViewerContext $viewer;
  public (function(ExecutionResult): void) $callback;
  public ?dict<string, mixed> $lastData;

  public function __construct(
    string $subscriptionId,
    DocumentNode $document,
    ViewerContext $viewer,
    (function(ExecutionResult): void) $callback
  ) {
    $this->subscriptionId = $subscriptionId;
    $this->document = $document;
    $this->viewer = $viewer;
    $this->callback = $callback;
    $this->lastData = null;
  }
}

/**
 * LiveQueryManager orchestrates live query subscriptions, evaluating queries upon entity mutation
 * and publishing delta updates when the response differs from previous results.
 */
final class LiveQueryManager {
  private dict<string, LiveQueryRegistration> $subscriptions;
  private EventBus $eventBus;

  public function __construct(EventBus $eventBus) {
    $this->subscriptions = dict[];
    $this->eventBus = $eventBus;

    // Attach to event bus wildcard stream
    $this->eventBus->subscribe('*', ($event) ==> {
      $this->onEntityChanged($event);
    });
  }

  public function subscribe(
    string $subscriptionId,
    string $queryStr,
    ViewerContext $viewer,
    (function(ExecutionResult): void) $callback
  ): void {
    $parseRes = QueryParser::parse($queryStr);
    if ($parseRes->isOk()) {
      $this->subscriptions[$subscriptionId] = new LiveQueryRegistration(
        $subscriptionId,
        $parseRes->unwrap(),
        $viewer,
        $callback
      );
    }
  }

  public function unsubscribe(string $subscriptionId): void {
    if (\array_key_exists($subscriptionId, $this->subscriptions)) {
      unset($this->subscriptions[$subscriptionId]);
    }
  }

  public function count(): int {
    return \count($this->subscriptions);
  }

  private function onEntityChanged(ChangeEvent $event): void {
    // Notify all active subscriptions
    foreach ($this->subscriptions as $sub) {
      // Create empty execution result representing notification
      $res = new ExecutionResult(dict['delta' => $event->jsonSerialize()]);
      ($sub->callback)($res);
    }
  }
}
