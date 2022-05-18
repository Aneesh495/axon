namespace Axon\Telemetry;

/**
 * Tracer creates and tracks distributed trace spans, supporting W3C traceparent propagation.
 */
final class Tracer {
  private string $serviceName;
  private vec<TraceSpan> $completedSpans;
  private int $maxStoredSpans;

  public function __construct(string $serviceName = 'axon-engine', int $maxStoredSpans = 5000) {
    $this->serviceName = $serviceName;
    $this->completedSpans = vec[];
    $this->maxStoredSpans = $maxStoredSpans;
  }

  public function startSpan(string $operationName, ?TraceSpan $parent = null): TraceSpan {
    $traceId = $parent !== null ? $parent->getTraceId() : $this->randomHex(32);
    $spanId = $this->randomHex(16);
    $parentSpanId = $parent !== null ? $parent->getSpanId() : null;

    $span = new TraceSpan($traceId, $spanId, $parentSpanId, $operationName);
    $span->setTag('service.name', $this->serviceName);

    return $span;
  }

  public function finishSpan(TraceSpan $span): void {
    $span->finish();
    if (\count($this->completedSpans) >= $this->maxStoredSpans) {
      $this->completedSpans = \array_slice($this->completedSpans, 1);
    }
    $this->completedSpans[] = $span;
  }

  public function getCompletedSpans(): vec<TraceSpan> {
    return $this->completedSpans;
  }

  public function clear(): void {
    $this->completedSpans = vec[];
  }

  private function randomHex(int $length): string {
    $bytes = \random_bytes((int)($length / 2));
    return \bin2hex($bytes);
  }
}
