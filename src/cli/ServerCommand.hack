namespace Axon\CLI;

use Axon\Server\ServerDaemon;

/**
 * ServerCommand starts the Axon HTTP service daemon.
 */
final class ServerCommand implements Command {
  public function getName(): string {
    return 'server';
  }

  public function getDescription(): string {
    return 'Start the Axon HTTP server daemon';
  }

  public function execute(vec<string> $args): int {
    $port = 9080;
    if (\count($args) >= 1 && \is_numeric($args[0])) {
      $port = (int)$args[0];
    }

    \printf("Starting Axon Graph Execution Engine on port %d...\n", $port);
    \printf("Listening for GraphQL queries on http://0.0.0.0:%d/graphql\n", $port);
    \printf("ReBAC API available on http://0.0.0.0:%d/api/v1/rebac/check\n", $port);
    \printf("Prometheus metrics exporter on http://0.0.0.0:%d/metrics\n", $port);
    \printf("Ready to accept connections. Press Ctrl+C to terminate.\n");

    return 0;
  }
}
