namespace Axon\Tests\Unit;

use Axon\Federation\ResultMerger;
use Axon\Federation\CircuitBreaker;
use Axon\Federation\CircuitState;

final class TestFederation {
  public static function run(): void {
    \printf("Running TestFederation...\n");

    // Test deep result merging across subgraphs
    $subgraphA = dict[
      'data' => dict[
        'User' => dict[
          'id' => 'usr-1',
          'username' => 'alice',
        ],
      ],
    ];

    $subgraphB = dict[
      'data' => dict[
        'User' => dict[
          'id' => 'usr-1',
          'email' => 'alice@example.com',
          'profile' => dict['bio' => 'Distributed systems engineer'],
        ],
      ],
    ];

    $merged = ResultMerger::merge(vec[$subgraphA, $subgraphB]);

    if (!\array_key_exists('User', $merged)) {
      throw new \RuntimeException("Merged output missing User entity");
    }

    $u = $merged['User'] as dict<string, mixed>;
    if ($u['username'] !== 'alice' || $u['email'] !== 'alice@example.com') {
      throw new \RuntimeException("Merged entity field values mismatch");
    }

    // Test circuit breaker
    $cb = new CircuitBreaker(3, 10);
    if ($cb->getState() !== CircuitState::CLOSED) {
      throw new \RuntimeException("Initial state should be CLOSED");
    }

    $cb->recordFailure();
    $cb->recordFailure();
    if ($cb->getState() !== CircuitState::CLOSED) {
      throw new \RuntimeException("State should still be CLOSED before threshold");
    }

    $cb->recordFailure(); // Threshold of 3 reached
    if ($cb->getState() !== CircuitState::OPEN) {
      throw new \RuntimeException("State should trip to OPEN after threshold");
    }

    \printf("TestFederation passed.\n");
  }
}
