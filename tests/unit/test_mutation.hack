namespace Axon\Tests\Unit;

use Axon\Reactive\MutationPipeline;
use Axon\Reactive\EventBus;
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

final class TestMutation {
  public static function run(): void {
    \printf("Running TestMutation...\n");

    $schema = new SchemaRegistry();
    $docFields = dict[
      'id' => new FieldDefinition('id', FieldType::id(), true, false),
      'title' => new FieldDefinition('title', FieldType::string(), false, false),
      'version' => new FieldDefinition('version', FieldType::int(), false, false, false, false, 1),
    ];
    $docEntity = new EntityDefinition('Document', 'axon_documents', $docFields);
    $schema->registerEntity($docEntity);

    $storage = new MemoryStorage();
    $wal = new WriteAheadLog();
    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();
    $checker = new CheckEngine($policies, $store);
    $eventBus = new EventBus();

    $eventsReceived = vec[];
    $eventBus->subscribe('Document.*', (ChangeEvent $e) ==> {
      $eventsReceived[] = $e;
    });

    $pipeline = new MutationPipeline($schema, $storage, $wal, $checker, $eventBus);
    $viewer = ViewerContext::system();

    // Insert entity
    $insertRes = $pipeline->insert($viewer, 'Document', 'doc-1', dict[
      'title' => 'Initial Document',
    ]);

    if ($insertRes->isErr()) {
      throw new \RuntimeException("Insert failed: " . $insertRes->unwrapErr());
    }

    $inserted = $insertRes->unwrap();
    if ($inserted['title'] !== 'Initial Document' || $inserted['version'] !== 1) {
      throw new \RuntimeException("Inserted document field mismatch");
    }

    // Verify storage and WAL
    if ($storage->get('axon_documents', 'doc-1') === null) {
      throw new \RuntimeException("Document not committed to storage engine");
    }
    if ($wal->getLatestLsn() !== 1) {
      throw new \RuntimeException("WAL should have recorded LSN 1");
    }

    // Update entity
    $updateRes = $pipeline->update($viewer, 'Document', 'doc-1', dict[
      'title' => 'Updated Document Title',
      'version' => 2,
    ]);
    if ($updateRes->isErr()) {
      throw new \RuntimeException("Update failed: " . $updateRes->unwrapErr());
    }

    $updated = $storage->get('axon_documents', 'doc-1') as nonnull;
    if ($updated['title'] !== 'Updated Document Title' || $updated['version'] !== 2) {
      throw new \RuntimeException("Updated record field mismatch in storage");
    }

    \printf("TestMutation passed.\n");
  }
}
