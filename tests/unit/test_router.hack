namespace Axon\Tests\Unit;

use Axon\Server\Router;
use Axon\Server\HttpRequest;
use Axon\Server\HttpResponse;

final class TestRouter {
  public static function run(): void {
    \printf("Running TestRouter...\n");

    $router = new Router();

    $router->get('/healthz', ($req, $params) ==> {
      return HttpResponse::text('OK');
    });

    $router->get('/api/v1/entities/:entity/:id', ($req, $params) ==> {
      $ent = $params['entity'] ?? '';
      $id = $params['id'] ?? '';
      return HttpResponse::json(dict['entity' => $ent, 'id' => $id]);
    });

    // Test static route
    $reqHealth = new HttpRequest('GET', '/healthz');
    $respHealth = $router->dispatch($reqHealth);
    if ($respHealth->getStatusCode() !== 200 || $respHealth->getBody() !== 'OK') {
      throw new \RuntimeException("Static route failed");
    }

    // Test parametric route
    $reqEntity = new HttpRequest('GET', '/api/v1/entities/Document/doc-42');
    $respEntity = $router->dispatch($reqEntity);
    if ($respEntity->getStatusCode() !== 200) {
      throw new \RuntimeException("Parametric route failed with status " . (string)$respEntity->getStatusCode());
    }

    $body = \json_decode($respEntity->getBody(), true);
    if (!\is_dict($body) || $body['entity'] !== 'Document' || $body['id'] !== 'doc-42') {
      throw new \RuntimeException("Parametric route variable extraction mismatch");
    }

    // Test 404
    $reqMissing = new HttpRequest('GET', '/nonexistent');
    $respMissing = $router->dispatch($reqMissing);
    if ($respMissing->getStatusCode() !== 404) {
      throw new \RuntimeException("Expected 404 for missing route");
    }

    \printf("TestRouter passed.\n");
  }
}
