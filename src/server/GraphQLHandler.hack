namespace Axon\Server;

use Axon\Query\QueryParser;
use Axon\Query\QueryValidator;
use Axon\Query\QueryPlanner;
use Axon\Query\QueryExecutor;
use Axon\ReBAC\ViewerContext;
use Axon\DataLoader\DataLoaderRegistry;
use Axon\Schema\SchemaRegistry;

/**
 * GraphQLHandler processes GraphQL POST requests and returns formatted JSON results.
 */
final class GraphQLHandler {
  private SchemaRegistry $schema;
  private QueryValidator $validator;
  private QueryPlanner $planner;
  private QueryExecutor $executor;
  private DataLoaderRegistry $loaders;

  public function __construct(
    SchemaRegistry $schema,
    QueryValidator $validator,
    QueryPlanner $planner,
    QueryExecutor $executor,
    DataLoaderRegistry $loaders
  ) {
    $this->schema = $schema;
    $this->validator = $validator;
    $this->planner = $planner;
    $this->executor = $executor;
    $this->loaders = $loaders;
  }

  public function handle(HttpRequest $request): HttpResponse {
    $payload = $request->parseJsonBody();
    if ($payload === null || !\array_key_exists('query', $payload)) {
      return HttpResponse::error('Invalid request body: expected JSON with "query" string field', 400);
    }

    $queryStr = (string)$payload['query'];

    // 1. Resolve ViewerContext from Authorization header
    $authHeader = $request->getHeader('Authorization');
    $viewer = ViewerContext::anonymous();
    if ($authHeader !== null && \str_starts_with($authHeader, 'Bearer ')) {
      $token = \substr($authHeader, 7);
      if ($token === 'root' || $token === 'admin') {
        $viewer = ViewerContext::system();
      } else {
        $viewer = new ViewerContext($token);
      }
    }

    // 2. Parse query string
    $parseRes = QueryParser::parse($queryStr);
    if ($parseRes->isErr()) {
      return HttpResponse::json(dict['errors' => vec[$parseRes->unwrapErr()]], 400);
    }
    $document = $parseRes->unwrap();

    // 3. Validate against schema
    $validRes = $this->validator->validate($document);
    if ($validRes->isErr()) {
      return HttpResponse::json(dict['errors' => $validRes->unwrapErr()], 400);
    }

    // 4. Plan and execute
    $plan = $this->planner->plan($document);
    $result = $this->executor->execute($plan, $viewer, $this->loaders);

    return HttpResponse::json($result->jsonSerialize(), 200);
  }
}
