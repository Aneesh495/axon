namespace Axon\Query;

/**
 * PageInfo specifies cursor navigation boundaries in Relay pagination.
 */
final class PageInfo implements \JsonSerializable {
  private bool $hasNextPage;
  private bool $hasPreviousPage;
  private ?string $startCursor;
  private ?string $endCursor;

  public function __construct(
    bool $hasNextPage,
    bool $hasPreviousPage,
    ?string $startCursor = null,
    ?string $endCursor = null
  ) {
    $this->hasNextPage = $hasNextPage;
    $this->hasPreviousPage = $hasPreviousPage;
    $this->startCursor = $startCursor;
    $this->endCursor = $endCursor;
  }

  public function hasNextPage(): bool {
    return $this->hasNextPage;
  }

  public function hasPreviousPage(): bool {
    return $this->hasPreviousPage;
  }

  public function getStartCursor(): ?string {
    return $this->startCursor;
  }

  public function getEndCursor(): ?string {
    return $this->endCursor;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'hasNextPage' => $this->hasNextPage,
      'hasPreviousPage' => $this->hasPreviousPage,
      'startCursor' => $this->startCursor,
      'endCursor' => $this->endCursor,
    ];
  }
}

/**
 * Edge wrapping a node with its unique opaque cursor.
 */
final class Edge<TNode> implements \JsonSerializable {
  private TNode $node;
  private string $cursor;

  public function __construct(TNode $node, string $cursor) {
    $this->node = $node;
    $this->cursor = $cursor;
  }

  public function getNode(): TNode {
    return $this->node;
  }

  public function getCursor(): string {
    return $this->cursor;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'node' => $this->node,
      'cursor' => $this->cursor,
    ];
  }
}

/**
 * Connection representing a paginated result set with edges and pageInfo.
 */
final class Connection<TNode> implements \JsonSerializable {
  private vec<Edge<TNode>> $edges;
  private PageInfo $pageInfo;
  private int $totalCount;

  public function __construct(
    vec<Edge<TNode>> $edges,
    PageInfo $pageInfo,
    int $totalCount = 0
  ) {
    $this->edges = $edges;
    $this->pageInfo = $pageInfo;
    $this->totalCount = $totalCount;
  }

  public function getEdges(): vec<Edge<TNode>> {
    return $this->edges;
  }

  public function getPageInfo(): PageInfo {
    return $this->pageInfo;
  }

  public function getTotalCount(): int {
    return $this->totalCount;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'edges' => $this->edges,
      'pageInfo' => $this->pageInfo,
      'totalCount' => $this->totalCount,
    ];
  }
}

/**
 * Helper utility for encoding and decoding opaque base64 pagination cursors.
 */
final class CursorCodec {
  public static function encode(int $offset): string {
    return \base64_encode('cursor:' . (string)$offset);
  }

  public static function decode(?string $cursor): int {
    if ($cursor === null || $cursor === '') {
      return 0;
    }
    $decoded = \base64_decode($cursor, true);
    if ($decoded === false) {
      return 0;
    }
    $prefix = 'cursor:';
    if (\str_starts_with($decoded, $prefix)) {
      return (int)\substr($decoded, \strlen($prefix));
    }
    return 0;
  }
}
