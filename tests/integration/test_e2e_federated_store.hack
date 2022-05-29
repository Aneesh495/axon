namespace Axon\Tests\Integration;

use Axon\Federation\FederatedSchema;
use Axon\Federation\SubgraphDefinition;
use Axon\Federation\MockSubgraphClient;
use Axon\Federation\ResultMerger;
use Axon\Federation\PlanDecomposer;
use Axon\Query\QueryParser;

final class TestE2EFederatedStore {
  public static function run(): void {
    \printf("Running TestE2EFederatedStore...\n");

    // Setup Supergraph schema
    $supergraph = new FederatedSchema();

    $accountsSubgraph = new SubgraphDefinition(
      'accounts',
      'http://accounts.service:4001/graphql',
      vec['User']
    );

    $catalogSubgraph = new SubgraphDefinition(
      'catalog',
      'http://catalog.service:4002/graphql',
      vec['Product']
    );

    $supergraph->registerSubgraph($accountsSubgraph);
    $supergraph->registerSubgraph($catalogSubgraph);

    // Mock clients
    $client = new MockSubgraphClient();
    $client->registerResponse('accounts', 'user', dict[
      'User' => dict[
        'id' => 'usr-1',
        'username' => 'alice',
      ],
    ]);
    $client->registerResponse('catalog', 'product', dict[
      'Product' => dict[
        'id' => 'prod-99',
        'sku' => 'SKU-QUANTUM-NODE',
        'price' => 199.95,
      ],
    ]);

    $decomposer = new PlanDecomposer($supergraph);
    $query = '{ User(id: "usr-1") { username } Product(id: "prod-99") { sku price } }';
    $doc = QueryParser::parse($query)->unwrap();

    $tasks = $decomposer->decompose($doc);
    if (\count($tasks) !== 2) {
      throw new \RuntimeException(\sprintf("Expected 2 decomposed subgraph tasks, got %d", \count($tasks)));
    }

    $subgraphResponses = vec[];
    foreach ($tasks as $task) {
      $resp = $client->executeQuery($task->getSubgraphName(), $task->getQuery());
      if ($resp->isErr()) {
        throw new \RuntimeException("Subgraph execution error: " . $resp->unwrapErr());
      }
      $subgraphResponses[] = $resp->unwrap();
    }

    $stitched = ResultMerger::merge($subgraphResponses);

    if (!\array_key_exists('User', $stitched) || !\array_key_exists('Product', $stitched)) {
      throw new \RuntimeException("Stitched supergraph result missing expected entities");
    }

    $u = $stitched['User'] as dict<string, mixed>;
    $p = $stitched['Product'] as dict<string, mixed>;

    if ($u['username'] !== 'alice' || $p['sku'] !== 'SKU-QUANTUM-NODE') {
      throw new \RuntimeException("Stitched entity property mismatch");
    }

    \printf("TestE2EFederatedStore passed.\n");
  }
}
