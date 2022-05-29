namespace Axon\Tests\Integration;

use Axon\Reactive\EventBus;
use Axon\Reactive\LiveQueryManager;
use Axon\Reactive\MutationPipeline;
use Axon\Reactive\ChangeEvent;
use Axon\Schema\SchemaRegistry;
use Axon\Schema\EntityDefinition;
use Axon\Schema\FieldDefinition;
use Axon\Schema\FieldType;
use Axon\Storage\MemoryStorage;
use Axon\Storage\WriteAheadLog;
use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\ViewerContext;
use Axon\Query\ExecutionResult;

final class TestE2ELiveFeed {
  public static function run(): void {
    \printf("Running TestE2ELiveFeed...\n");

    $eventBus = new EventBus();
    $liveManager = new LiveQueryManager($eventBus);

    $schema = new SchemaRegistry();
    $msgFields = dict[
      'id' => new FieldDefinition('id', FieldType::id(), true, false),
      'body' => new FieldDefinition('body', FieldType::string(), false, false),
    ];
    $schema->registerEntity(new EntityDefinition('Message', 'axon_messages', $msgFields));

    $storage = new MemoryStorage();
    $wal = new WriteAheadLog();
    $tupleStore = new MemoryTupleStore();
    $policies = new PolicyRegistry();
    $checker = new CheckEngine($policies, $tupleStore);

    $pipeline = new MutationPipeline($schema, $storage, $wal, $checker, $eventBus);

    $notifications = vec[];
    $liveManager->subscribe(
      'sub-feed',
      '{ Message(id: "msg-1") { body } }',
      ViewerContext::system(),
      (ExecutionResult $res) ==> {
        $notifications[] = $res;
      }
    );

    // Perform mutation
    $pipeline->insert(ViewerContext::system(), 'Message', 'msg-1', dict[
      'body' => 'Stream operational',
    ]);

    if (\count($notifications) !== 1) {
      throw new \RuntimeException("Live feed subscription did not receive notification on insert");
    }

    \printf("TestE2ELiveFeed passed.\n");
  }
}
