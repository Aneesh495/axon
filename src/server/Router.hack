namespace Axon\Server;

/**
 * RouteMatch contains the matched handler and extracted path parameters.
 */
final class RouteMatch {
  private (function(HttpRequest, dict<string, string>): HttpResponse) $handler;
  private dict<string, string> $params;

  public function __construct(
    (function(HttpRequest, dict<string, string>): HttpResponse) $handler,
    dict<string, string> $params = dict[]
  ) {
    $this->handler = $handler;
    $this->params = $params;
  }

  public function getHandler(): (function(HttpRequest, dict<string, string>): HttpResponse) {
    return $this->handler;
  }

  public function getParams(): dict<string, string> {
    return $this->params;
  }
}

/**
 * Router resolves HTTP request paths to matched handlers with path variable binding.
 */
final class Router {
  private dict<string, dict<string, (function(HttpRequest, dict<string, string>): HttpResponse)>> $routes;

  public function __construct() {
    $this->routes = dict[];
  }

  public function addRoute(
    string $method,
    string $path,
    (function(HttpRequest, dict<string, string>): HttpResponse) $handler
  ): void {
    $m = \strtoupper($method);
    if (!\array_key_exists($m, $this->routes)) {
      $this->routes[$m] = dict[];
    }
    $this->routes[$m][$path] = $handler;
  }

  public function get(string $path, (function(HttpRequest, dict<string, string>): HttpResponse) $handler): void {
    $this->addRoute('GET', $path, $handler);
  }

  public function post(string $path, (function(HttpRequest, dict<string, string>): HttpResponse) $handler): void {
    $this->addRoute('POST', $path, $handler);
  }

  public function delete(string $path, (function(HttpRequest, dict<string, string>): HttpResponse) $handler): void {
    $this->addRoute('DELETE', $path, $handler);
  }

  public function dispatch(HttpRequest $request): HttpResponse {
    $method = $request->getMethod();
    $path = $request->getPath();

    if (!\array_key_exists($method, $this->routes)) {
      return HttpResponse::error('Method Not Allowed', 405);
    }

    // 1. Direct path lookup
    if (\array_key_exists($path, $this->routes[$method])) {
      $handler = $this->routes[$method][$path];
      return $handler($request, dict[]);
    }

    // 2. Parametric matching (e.g. /api/v1/entities/:entity/:id)
    $pathSegments = \explode('/', \trim($path, '/'));

    foreach ($this->routes[$method] as $routePath => $handler) {
      $routeSegments = \explode('/', \trim($routePath, '/'));
      if (\count($pathSegments) !== \count($routeSegments)) {
        continue;
      }

      $matches = true;
      $params = dict[];

      for ($i = 0; $i < \count($pathSegments); $i++) {
        $pSeg = $pathSegments[$i];
        $rSeg = $routeSegments[$i];

        if (\str_starts_with($rSeg, ':')) {
          $paramName = \substr($rSeg, 1);
          $params[$paramName] = $pSeg;
        } else if ($pSeg !== $rSeg) {
          $matches = false;
          break;
        }
      }

      if ($matches) {
        return $handler($request, $params);
      }
    }

    return HttpResponse::error('Not Found', 404);
  }
}
