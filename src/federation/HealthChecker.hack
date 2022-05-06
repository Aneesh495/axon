namespace Axon\Federation;

/**
 * Circuit breaker states for upstream subgraph services.
 */
enum CircuitState: string {
  CLOSED = 'CLOSED';
  OPEN = 'OPEN';
  HALF_OPEN = 'HALF_OPEN';
}

/**
 * CircuitBreaker tracks failure rates and trips open to prevent cascading failures.
 */
final class CircuitBreaker {
  private CircuitState $state;
  private int $failureThreshold;
  private int $resetTimeoutSeconds;
  private int $consecutiveFailures;
  private int $lastStateChangeTimestamp;

  public function __construct(int $failureThreshold = 5, int $resetTimeoutSeconds = 30) {
    $this->state = CircuitState::CLOSED;
    $this->failureThreshold = $failureThreshold;
    $this->resetTimeoutSeconds = $resetTimeoutSeconds;
    $this->consecutiveFailures = 0;
    $this->lastStateChangeTimestamp = (int)\time();
  }

  public function getState(): CircuitState {
    $now = (int)\time();
    if ($this->state === CircuitState::OPEN && ($now - $this->lastStateChangeTimestamp) >= $this->resetTimeoutSeconds) {
      $this->state = CircuitState::HALF_OPEN;
      $this->lastStateChangeTimestamp = $now;
    }
    return $this->state;
  }

  public function recordSuccess(): void {
    $this->consecutiveFailures = 0;
    $this->state = CircuitState::CLOSED;
    $this->lastStateChangeTimestamp = (int)\time();
  }

  public function recordFailure(): void {
    $this->consecutiveFailures++;
    if ($this->consecutiveFailures >= $this->failureThreshold) {
      $this->state = CircuitState::OPEN;
      $this->lastStateChangeTimestamp = (int)\time();
    }
  }

  public function canExecute(): bool {
    $current = $this->getState();
    return $current === CircuitState::CLOSED || $current === CircuitState::HALF_OPEN;
  }
}

/**
 * HealthChecker monitors all federated subgraphs and maintains circuit breakers.
 */
final class HealthChecker {
  private dict<string, CircuitBreaker> $breakers;

  public function __construct() {
    $this->breakers = dict[];
  }

  public function registerSubgraph(string $name, int $failureThreshold = 5): void {
    $this->breakers[$name] = new CircuitBreaker($failureThreshold);
  }

  public function getBreaker(string $name): ?CircuitBreaker {
    return \array_key_exists($name, $this->breakers) ? $this->breakers[$name] : null;
  }

  public function isHealthy(string $name): bool {
    $breaker = $this->getBreaker($name);
    return $breaker !== null ? $breaker->canExecute() : true;
  }
}
