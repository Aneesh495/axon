namespace Axon\Tests\Unit;

use Axon\Schema\FieldType;
use Axon\Schema\FieldDefinition;
use Axon\Schema\EdgeDefinition;
use Axon\Schema\EdgeCardinality;
use Axon\Schema\EntityDefinition;
use Axon\Schema\SchemaRegistry;

final class TestSchema {
  public static function run(): void {
    \printf("Running TestSchema...\n");

    $userFields = dict[
      'id' => new FieldDefinition('id', FieldType::id(), true, false),
      'username' => new FieldDefinition('username', FieldType::string(), false, false, true),
      'age' => new FieldDefinition('age', FieldType::int(), false, true),
    ];

    $docFields = dict[
      'id' => new FieldDefinition('id', FieldType::id(), true, false),
      'title' => new FieldDefinition('title', FieldType::string(), false, false),
      'ownerId' => new FieldDefinition('ownerId', FieldType::id(), false, false),
    ];

    $docEdges = dict[
      'owner' => new EdgeDefinition(
        'owner',
        'Document',
        'User',
        EdgeCardinality::MANY_TO_ONE,
        'ownerId',
        null,
        'documents'
      ),
    ];

    $userEdges = dict[
      'documents' => new EdgeDefinition(
        'documents',
        'User',
        'Document',
        EdgeCardinality::ONE_TO_MANY,
        null,
        null,
        'owner'
      ),
    ];

    $userEntity = new EntityDefinition('User', 'axon_users', $userFields, $userEdges);
    $docEntity = new EntityDefinition('Document', 'axon_documents', $docFields, $docEdges);

    $registry = new SchemaRegistry();
    $registry->registerEntity($userEntity);
    $registry->registerEntity($docEntity);

    $compileRes = $registry->compile();
    if ($compileRes->isErr()) {
      throw new \RuntimeException("Schema compilation failed: " . \implode(', ', $compileRes->unwrapErr()));
    }

    // Test record validation
    $validRecord = dict[
      'id' => 'usr-1',
      'username' => 'alice',
      'age' => 30,
    ];
    $recRes = $userEntity->validateRecord($validRecord);
    if ($recRes->isErr()) {
      throw new \RuntimeException("Record validation failed for valid data");
    }

    // Test non-nullable rejection
    $invalidRecord = dict[
      'id' => 'usr-1',
      'username' => null,
    ];
    $recInvalid = $userEntity->validateRecord($invalidRecord);
    if ($recInvalid->isOk()) {
      throw new \RuntimeException("Record validation should reject null for non-nullable username");
    }

    \printf("TestSchema passed.\n");
  }
}
