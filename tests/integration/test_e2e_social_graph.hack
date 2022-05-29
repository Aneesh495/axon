namespace Axon\Tests\Integration;

use Axon\Schema\SchemaRegistry;
use Axon\Schema\EntityDefinition;
use Axon\Schema\FieldDefinition;
use Axon\Schema\FieldType;
use Axon\Schema\EdgeDefinition;
use Axon\Schema\EdgeCardinality;
use Axon\Storage\MemoryStorage;
use Axon\Storage\WriteAheadLog;
use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\NamespaceConfig;
use Axon\ReBAC\RelationRule;
use Axon\ReBAC\UnionRewrite;
use Axon\ReBAC\ThisRewrite;
use Axon\ReBAC\ComputedUsersetRewrite;
use Axon\ReBAC\Subject;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\ViewerContext;
use Axon\Reactive\EventBus;
use Axon\Reactive\MutationPipeline;
use Axon\Query\FieldResolver;
use Axon\Query\QueryExecutor;
use Axon\Query\QueryPlanner;
use Axon\Query\QueryParser;
use Axon\DataLoader\DataLoaderRegistry;
use Axon\DataLoader\EntityLoader;

final class TestE2ESocialGraph {
  public static function run(): void {
    \printf("Running TestE2ESocialGraph...\n");

    // 1. Setup Schema
    $schema = new SchemaRegistry();

    $userFields = dict[
      'id' => new FieldDefinition('id', FieldType::id(), true, false),
      'username' => new FieldDefinition('username', FieldType::string(), false, false, true),
      'email' => new FieldDefinition('email', FieldType::string(), false, false, true),
    ];
    $schema->registerEntity(new EntityDefinition('User', 'axon_users', $userFields));

    $postFields = dict[
      'id' => new FieldDefinition('id', FieldType::id(), true, false),
      'authorId' => new FieldDefinition('authorId', FieldType::id(), false, false),
      'title' => new FieldDefinition('title', FieldType::string(), false, false),
      'content' => new FieldDefinition('content', FieldType::string(), false, false),
    ];
    $postEdges = dict[
      'author' => new EdgeDefinition('author', 'Post', 'User', EdgeCardinality::MANY_TO_ONE, 'authorId'),
    ];
    $schema->registerEntity(new EntityDefinition('Post', 'axon_posts', $postFields, $postEdges, vec[], 'post'));

    // 2. Setup ReBAC Policies:
    // Post:
    // - owner: this
    // - viewer: this | owner
    $policies = new PolicyRegistry();
    $postNs = new NamespaceConfig('post');
    $postNs->addRule(new RelationRule('owner', new ThisRewrite()));
    $postNs->addRule(new RelationRule('viewer', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('owner'),
    ])));
    $policies->registerNamespace($postNs);

    // 3. Storage, WAL, CheckEngine, Pipeline
    $storage = new MemoryStorage();
    $wal = new WriteAheadLog();
    $tupleStore = new MemoryTupleStore();
    $checker = new CheckEngine($policies, $tupleStore);
    $eventBus = new EventBus();
    $pipeline = new MutationPipeline($schema, $storage, $wal, $checker, $eventBus);

    $alice = new Subject('user', 'usr-alice');
    $bob = new Subject('user', 'usr-bob');
    $charlie = new Subject('user', 'usr-charlie');

    // 4. Populate Users and Posts
    $pipeline->insert(ViewerContext::system(), 'User', 'usr-alice', dict[
      'username' => 'alice',
      'email' => 'alice@network.org',
    ]);
    $pipeline->insert(ViewerContext::system(), 'User', 'usr-bob', dict[
      'username' => 'bob',
      'email' => 'bob@network.org',
    ]);

    $pipeline->insert(ViewerContext::system(), 'Post', 'pst-101', dict[
      'authorId' => 'usr-alice',
      'title' => 'Deep Dive into Distributed Graphs',
      'content' => 'Exploring async DataLoader coalescing...',
    ]);

    // Alice is owner of pst-101
    $tupleStore->insert(new RelationTuple('post', 'pst-101', 'owner', $alice));
    // Alice shares pst-101 with Bob explicitly as viewer
    $tupleStore->insert(new RelationTuple('post', 'pst-101', 'viewer', $bob));

    // 5. Query execution with privacy enforcement
    $resolver = new FieldResolver($checker);
    $executor = new QueryExecutor($schema, $resolver);
    $planner = new QueryPlanner($schema);

    $loaders = new DataLoaderRegistry();
    $loaders->registerEntityLoader(new EntityLoader('Post', (vec<string> $ids) ==> {
      $recs = dict[];
      foreach ($ids as $id) {
        $recs[$id] = $storage->get('axon_posts', $id);
      }
      return $recs;
    }));

    $query = '{ Post(id: "pst-101") { title content } }';
    $doc = QueryParser::parse($query)->unwrap();
    $plan = $planner->plan($doc);

    // Bob queries pst-101 (authorized viewer)
    $bobContext = new ViewerContext('usr-bob');
    $resBob = $executor->execute($plan, $bobContext, $loaders);
    $bobData = $resBob->getData();
    if (!\array_key_exists('Post', $bobData) || $bobData['Post'] === null) {
      throw new \RuntimeException("Bob should be able to view pst-101");
    }

    // Charlie queries pst-101 (unauthorized actor -> privacy masked to null)
    $charlieContext = new ViewerContext('usr-charlie');
    $resCharlie = $executor->execute($plan, $charlieContext, $loaders);
    $charlieData = $resCharlie->getData();
    if (\array_key_exists('Post', $charlieData) && $charlieData['Post'] !== null) {
      throw new \RuntimeException("Charlie must not view pst-101; expected null masked result");
    }

    \printf("TestE2ESocialGraph passed.\n");
  }
}
