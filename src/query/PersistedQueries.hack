namespace Axon\Query;

use Axon\Core\Result;

/**
 * PersistedQueries maintains an automated persisted query (APQ) hash registry.
 */
final class PersistedQueries {
  private dict<string, DocumentNode> $cache;

  public function __construct() {
    $this->cache = dict[];
  }

  public function get(string $sha256Hash): ?DocumentNode {
    return \array_key_exists($sha256Hash, $this->cache) ? $this->cache[$sha256Hash] : null;
  }

  public function put(string $sha256Hash, DocumentNode $doc): void {
    $this->cache[$sha256Hash] = $doc;
  }

  public function registerFromQuery(string $queryString): Result<string, string> {
    $parseRes = QueryParser::parse($queryString);
    if ($parseRes->isErr()) {
      return Result::err($parseRes->unwrapErr());
    }
    $doc = $parseRes->unwrap();
    $hash = \hash('sha256', $queryString);
    $this->put($hash, $doc);
    return Result::ok($hash);
  }

  public function count(): int {
    return \count($this->cache);
  }
}
