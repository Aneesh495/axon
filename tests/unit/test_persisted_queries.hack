namespace Axon\Tests\Unit;

use Axon\Query\PersistedQueries;

final class TestPersistedQueries {
  public static function run(): void {
    \printf("Running TestPersistedQueries...\n");

    $apq = new PersistedQueries();
    $query = '{ Document(id: "doc-1") { title } }';

    $hashRes = $apq->registerFromQuery($query);
    if ($hashRes->isErr()) {
      throw new \RuntimeException("Registration failed: " . $hashRes->unwrapErr());
    }

    $hash = $hashRes->unwrap();
    $cachedDoc = $apq->get($hash);

    if ($cachedDoc === null) {
      throw new \RuntimeException("Persisted query not found by hash");
    }

    \printf("TestPersistedQueries passed.\n");
  }
}
