namespace Axon\Tests\Unit;

use Axon\Query\QueryParser;
use Axon\Query\QueryPlanner;
use Axon\Query\QueryExecutor;
use Axon\Query\FieldResolver;
use Axon\Schema\SchemaRegistry;
use Axon\DataLoader\DataLoaderRegistry;
use Axon\DataLoader\EntityLoader;
use Axon\ReBAC\ViewerContext;
use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;

final class TestQueryExecutor {
  public static function run(): void {
    \printf("Running TestQueryExecutor...\n");

    $schema = new SchemaRegistry();
    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();
    $checker = new CheckEngine($policies, $store);
    $resolver = new FieldResolver($checker);

    $executor = new QueryExecutor($schema, $resolver);
    $planner = new QueryPlanner($schema);

    $loaders = new DataLoaderRegistry();
    $docLoader = new EntityLoader('Document', (vec<string> $ids) ==> {
      $records = dict[];
      foreach ($ids as $id) {
        $records[$id] = dict[
          'id' => $id,
          'title' => 'Architecture Guide',
          'content' => 'Distributed consensus details...',
        ];
      }
      return $records;
    });
    $loaders->registerEntityLoader($docLoader);

    $query = '{ Document(id: "doc-1") { title content } }';
    $doc = QueryParser::parse($query)->unwrap();
    $plan = $planner->plan($doc);

    $viewer = ViewerContext::system();
    $result = $executor->execute($plan, $viewer, $loaders);

    if ($result->hasErrors()) {
      throw new \RuntimeException("Execution had unexpected errors: " . \implode(', ', $result->getErrors()));
    }

    $data = $result->getData();
    if (!\array_key_exists('Document', $data) || $data['Document'] === null) {
      throw new \RuntimeException("Missing Document in execution data");
    }

    $docData = $data['Document'] as dict<string, mixed>;
    if ($docData['title'] !== 'Architecture Guide') {
      throw new \RuntimeException("Document title mismatch in executed response");
    }

    \printf("TestQueryExecutor passed.\n");
  }
}
