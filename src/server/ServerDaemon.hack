namespace Axon\Server;

use Axon\Telemetry\MetricsCollector;
use Axon\Telemetry\PrometheusExporter;

/**
 * ServerDaemon wires all HTTP handlers and manages the server request dispatch loop.
 */
final class ServerDaemon {
  private Router $router;
  private MetricsCollector $metrics;
  private PrometheusExporter $promExporter;
  private bool $isRunning;

  public function __construct(
    GraphQLHandler $graphqlHandler,
    ReBACHandler $rebacHandler,
    MetricsCollector $metrics
  ) {
    $this->router = new Router();
    $this->metrics = $metrics;
    $this->promExporter = new PrometheusExporter($metrics);
    $this->isRunning = false;

    // Register routes
    $this->router->post('/graphql', ($req, $_) ==> $graphqlHandler->handle($req));
    $this->router->post('/api/v1/rebac/check', ($req, $_) ==> $rebacHandler->handleCheck($req));
    $this->router->post('/api/v1/rebac/expand', ($req, $_) ==> $rebacHandler->handleExpand($req));
    $this->router->post('/api/v1/rebac/write', ($req, $_) ==> $rebacHandler->handleWrite($req));

    $this->router->get('/healthz', ($req, $_) ==> {
      return HttpResponse::json(dict[
        'status' => 'healthy',
        'timestamp' => (int)\time(),
        'service' => 'axon-engine',
      ]);
    });

    $this->router->get('/metrics', ($req, $_) ==> {
      $text = $this->promExporter->export();
      return HttpResponse::text($text);
    });
  }

  public function getRouter(): Router {
    return $this->router;
  }

  public function handleRequest(HttpRequest $request): HttpResponse {
    $this->metrics->increment('requests_total');
    $startTime = \microtime(true);

    $response = $this->router->dispatch($request);

    $latencyMs = (\microtime(true) - $startTime) * 1000.0;
    $this->metrics->observeHistogram('request_duration_ms', (float)$latencyMs);

    return $response;
  }
}
