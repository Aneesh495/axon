namespace Axon\Server;

/**
 * HttpRequest represents an incoming HTTP network request.
 */
final class HttpRequest {
  private string $method;
  private string $path;
  private dict<string, string> $headers;
  private dict<string, string> $queryParams;
  private string $body;
  private string $clientIp;

  public function __construct(
    string $method,
    string $path,
    dict<string, string> $headers = dict[],
    dict<string, string> $queryParams = dict[],
    string $body = '',
    string $clientIp = '127.0.0.1'
  ) {
    $this->method = \strtoupper($method);
    $this->path = $path;
    $this->headers = $headers;
    $this->queryParams = $queryParams;
    $this->body = $body;
    $this->clientIp = $clientIp;
  }

  public function getMethod(): string {
    return $this->method;
  }

  public function getPath(): string {
    return $this->path;
  }

  public function getHeader(string $name): ?string {
    $lower = \strtolower($name);
    foreach ($this->headers as $k => $v) {
      if (\strtolower($k) === $lower) {
        return $v;
      }
    }
    return null;
  }

  public function getQueryParam(string $name): ?string {
    return \array_key_exists($name, $this->queryParams) ? $this->queryParams[$name] : null;
  }

  public function getBody(): string {
    return $this->body;
  }

  public function getClientIp(): string {
    return $this->clientIp;
  }

  public function parseJsonBody(): ?dict<string, mixed> {
    if ($this->body === '') {
      return null;
    }
    $decoded = \json_decode($this->body, true);
    return \is_dict($decoded) ? $decoded : null;
  }
}
