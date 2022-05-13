namespace Axon\Reactive;

use Axon\Core\Result;
use Axon\ReBAC\ViewerContext;
use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;
use Axon\Schema\SchemaRegistry;
use Axon\Storage\StorageEngine;
use Axon\Storage\WriteAheadLog;
use Axon\Storage\WALOpType;

/**
 * MutationPipeline coordinates transactional mutations, validating permissions,
 * enforcing schema contracts, persisting state, logging to WAL, and emitting events.
 */
final class MutationPipeline {
  private SchemaRegistry $schema;
  private StorageEngine $storage;
  private WriteAheadLog $wal;
  private CheckEngine $checker;
  private EventBus $eventBus;

  public function __construct(
    SchemaRegistry $schema,
    StorageEngine $storage,
    WriteAheadLog $wal,
    CheckEngine $checker,
    EventBus $eventBus
  ) {
    $this->schema = $schema;
    $this->storage = $storage;
    $this->wal = $wal;
    $this->checker = $checker;
    $this->eventBus = $eventBus;
  }

  public function insert(
    ViewerContext $viewer,
    string $entityName,
    string $id,
    dict<string, mixed> $fields
  ): Result<dict<string, mixed>, string> {
    $entity = $this->schema->getEntity($entityName);
    if ($entity === null) {
      return Result::err(\sprintf('Unknown entity type: %s', $entityName));
    }

    $tableName = $entity->getTableName();
    if ($this->storage->get($tableName, $id) !== null) {
      return Result::err(\sprintf('Entity "%s" with id "%s" already exists', $entityName, $id));
    }

    $fields['id'] = $id;
    $validation = $entity->validateRecord($fields);
    if ($validation->isErr()) {
      return Result::err($validation->unwrapErr());
    }

    $validRecord = $validation->unwrap();

    // 1. Append to Write-Ahead Log
    $payloadJson = \json_encode($validRecord);
    $lsn = $this->wal->append(WALOpType::PUT, $tableName, $id, $payloadJson);

    // 2. Commit to storage
    $this->storage->put($tableName, $id, $validRecord);

    // 3. Emit change event
    $event = new ChangeEvent(
      \uniqid('evt_'),
      $entityName,
      ChangeOp::INSERT,
      null,
      $validRecord,
      $lsn,
      (int)\time(),
      $viewer->getUserId()
    );
    $this->eventBus->publish($entityName . '.created', $event);

    return Result::ok($validRecord);
  }

  public function update(
    ViewerContext $viewer,
    string $entityName,
    string $id,
    dict<string, mixed> $updates
  ): Result<dict<string, mixed>, string> {
    $entity = $this->schema->getEntity($entityName);
    if ($entity === null) {
      return Result::err(\sprintf('Unknown entity type: %s', $entityName));
    }

    $tableName = $entity->getTableName();
    $existing = $this->storage->get($tableName, $id);
    if ($existing === null) {
      return Result::err(\sprintf('Entity "%s" with id "%s" not found', $entityName, $id));
    }

    // Permission check: viewer must possess editor relation on entity
    if (!$viewer->isOmnipotent()) {
      $ns = $entity->getRebacNamespace() ?? \strtolower($entityName);
      $req = new CheckRequest($ns, $id, 'editor', $viewer->toSubject());
      $check = $this->checker->check($req);
      if (!$check->isAllowed()) {
        return Result::err(\sprintf('Forbidden: viewer lacks editor permission on %s:%s', $ns, $id));
      }
    }

    // Merge updates into existing record
    $merged = $existing;
    foreach ($updates as $k => $v) {
      if ($k !== 'id') {
        $merged[$k] = $v;
      }
    }

    $validation = $entity->validateRecord($merged);
    if ($validation->isErr()) {
      return Result::err($validation->unwrapErr());
    }

    $validRecord = $validation->unwrap();

    // 1. WAL append
    $payloadJson = \json_encode($validRecord);
    $lsn = $this->wal->append(WALOpType::PUT, $tableName, $id, $payloadJson);

    // 2. Commit to storage
    $this->storage->put($tableName, $id, $validRecord);

    // 3. Emit change event
    $event = new ChangeEvent(
      \uniqid('evt_'),
      $entityName,
      ChangeOp::UPDATE,
      $existing,
      $validRecord,
      $lsn,
      (int)\time(),
      $viewer->getUserId()
    );
    $this->eventBus->publish($entityName . '.updated', $event);

    return Result::ok($validRecord);
  }

  public function delete(
    ViewerContext $viewer,
    string $entityName,
    string $id
  ): Result<bool, string> {
    $entity = $this->schema->getEntity($entityName);
    if ($entity === null) {
      return Result::err(\sprintf('Unknown entity type: %s', $entityName));
    }

    $tableName = $entity->getTableName();
    $existing = $this->storage->get($tableName, $id);
    if ($existing === null) {
      return Result::ok(false);
    }

    if (!$viewer->isOmnipotent()) {
      $ns = $entity->getRebacNamespace() ?? \strtolower($entityName);
      $req = new CheckRequest($ns, $id, 'owner', $viewer->toSubject());
      $check = $this->checker->check($req);
      if (!$check->isAllowed()) {
        return Result::err(\sprintf('Forbidden: viewer lacks owner permission on %s:%s', $ns, $id));
      }
    }

    // 1. WAL append
    $lsn = $this->wal->append(WALOpType::DELETE, $tableName, $id, '');

    // 2. Storage delete
    $this->storage->delete($tableName, $id);

    // 3. Emit change event
    $event = new ChangeEvent(
      \uniqid('evt_'),
      $entityName,
      ChangeOp::DELETE,
      $existing,
      null,
      $lsn,
      (int)\time(),
      $viewer->getUserId()
    );
    $this->eventBus->publish($entityName . '.deleted', $event);

    return Result::ok(true);
  }
}
