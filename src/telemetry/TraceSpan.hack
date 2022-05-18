namespace Axon\Telemetry;

/**
 * TraceEvent records an annotated timestamped event within a span lifetime.
 */
final class TraceEvent implements \JsonSerializable {
  private string $name;
  private int $timestampMicros;
  private dict<string, string> $attributes;

  public function __construct(string $name, int $timestampMicros, dict<string, string> $attributes = dict[]) {
    $this->name = $name;
    $this->timestampMicros = $timestampMicros;
    $this->attributes = $attributes;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getTimestampMicros(): int {
    return $this->timestampMicros;
  }

  public function getAttributes(): dict<string, string> {
    return $this->attributes;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'name' => $this->name,
      'time_us' => $this->timestampMicros,
      'attrs' => $this->attributes,
    ];
  }
}

/**
 * TraceSpan encapsulates a distributed tracing interval compatible with OpenTelemetry standards.
 */
final class TraceSpan implements \JsonSerializable {
  private string $traceId;
  private string $spanId;
  private ?string $parentSpanId;
  private string $operationName;
  private int $startMicros;
  private int $endMicros;
  private dict<string, string> $tags;
  private vec<TraceEvent> $events;

  public function __construct(
    string $traceId,
    string $spanId,
    ?string $parentSpanId,
    string $operationName,
    int $startMicros = 0
  ) {
    $this->traceId = $traceId;
    $this->spanId = $spanId;
    $this->parentSpanId = $parentSpanId;
    $this->operationName = $operationName;
    $this->startMicros = $startMicros > 0 ? $startMicros : (int)(\microtime(true) * 1000000.0);
    $this->endMicros = 0;
    $this->tags = dict[];
    $this->events = vec[];
  }

  public function getTraceId(): string {
    return $this->traceId;
  }

  public function getSpanId(): string {
    return $this->spanId;
  }

  public function getParentSpanId(): ?string {
    return $this->parentSpanId;
  }

  public function getOperationName(): string {
    return $this->operationName;
  }

  public function setTag(string $key, string $value): void {
    $this->tags[$key] = $value;
  }

  public function addEvent(string $name, dict<string, string> $attributes = dict[]): void {
    $nowUs = (int)(\microtime(true) * 1000000.0);
    $this->events[] = new TraceEvent($name, $nowUs, $attributes);
  }

  public function finish(int $endMicros = 0): void {
    $this->endMicros = $endMicros > 0 ? $endMicros : (int)(\microtime(true) * 1000000.0);
  }

  public function getDurationMicros(): int {
    if ($this->endMicros <= 0) {
      $nowUs = (int)(\microtime(true) * 1000000.0);
      return $nowUs - $this->startMicros;
    }
    return $this->endMicros - $this->startMicros;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'trace_id' => $this->traceId,
      'span_id' => $this->spanId,
      'parent_span_id' => $this->parentSpanId,
      'op' => $this->operationName,
      'start_us' => $this->startMicros,
      'end_us' => $this->endMicros,
      'duration_us' => $this->getDurationMicros(),
      'tags' => $this->tags,
      'events' => $this->events,
    ];
  }
}
