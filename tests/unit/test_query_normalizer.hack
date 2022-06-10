namespace Axon\Tests\Unit;

use Axon\Query\QueryParser;
use Axon\Query\QueryNormalizer;

final class TestQueryNormalizer {
  public static function run(): void {
    \printf("Running TestQueryNormalizer...\n");

    $query = 'query   TestOp  {   Document  ( id: "doc-1" ) {   title   content   }   }';
    $doc = QueryParser::parse($query)->unwrap();

    $normalized = QueryNormalizer::normalize($doc);
    if (!\str_contains($normalized, 'Document(id:doc-1){title content}')) {
      throw new \RuntimeException("Normalized query string format mismatch: " . $normalized);
    }

    \printf("TestQueryNormalizer passed.\n");
  }
}
