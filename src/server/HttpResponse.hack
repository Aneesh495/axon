namespace Axon\Server;

/**
 * HttpResponse represents an outgoing HTTP network response.
 */
final class HttpResponse {
  private int $statusCode;
  private dict<string, string> $headers;
  private string $body;

  public function __construct(
    int $statusCode = 200,
    dict<string, string> $headers = dict[],
    string $body = ''
  ) {
    $this->statusCode = $statusCode;
    $this->headers = $headers;
    $this->body = $body;
  }

  public function getStatusCode(): int {
    return $this->statusCode;
  }

  public function getHeaders(): dict<string, string> {
    return $this->headers;
  }

  public function getBody(): string {
    return $this->body;
  }

  public static function json(mixed $data, int $statusCode = 200): HttpResponse {
    $jsonStr = \json_encode($data, \JSON_PRETTY_PRINT | \JSON_UNESCAPED_SLASHES);
    $headers = dict[
      'Content-Type' => 'application/json; charset=utf-8',
      'Content-Length' => (string)\strlen($jsonStr),
    ];
    return new HttpResponse($statusCode, $headers, $jsonStr);
  }

  public static function text(string $text, int $statusCode = 200): HttpResponse {
    $headers = dict[
      'Content-Type' => 'text/plain; charset=utf-8',
      'Content-Length' => (string)\strlen($text),
    ];
    return new HttpResponse($statusCode, $headers, $text);
  }

  public static function error(string $message, int $statusCode = 400): HttpResponse {
    return self::json(dict['error' => $message], $statusCode);
  }
}
