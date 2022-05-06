namespace Axon\Federation;

use Axon\Core\Result;

/**
 * SubgraphClient defines the contract for communicating with remote upstream subgraph services.
 */
interface SubgraphClient {
  public function executeQuery(
    string $subgraphName,
    string $query,
    dict<string, mixed> $variables = dict[]
  ): Result<dict<string, mixed>, string>;
}

/**
 * MockSubgraphClient for local in-memory execution and integration testing.
 */
final class MockSubgraphClient implements SubgraphClient {
  private dict<string, dict<string, mixed>> $responses;

  public function __construct() {
    $this->responses = dict[];
  }

  public function registerResponse(string $subgraphName, string $queryKey, dict<string, mixed> $data): void {
    $key = \sprintf('%s:%s', $subgraphName, $queryKey);
    $this->responses[$key] = $data;
  }

  public function executeQuery(
    string $subgraphName,
    string $query,
    dict<string, mixed> $variables = dict[]
  ): Result<dict<string, mixed>, string> {
    foreach ($this->responses as $key => $data) {
      if (\str_starts_with($key, $subgraphName . ':')) {
        return Result::ok($data);
      }
    }
    return Result::err(\sprintf('No mocked response for subgraph "%s"', $subgraphName));
  }
}
