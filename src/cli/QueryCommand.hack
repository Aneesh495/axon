namespace Axon\CLI;

use Axon\Query\QueryParser;
use Axon\Query\QueryValidator;
use Axon\Query\QueryPlanner;
use Axon\Query\QueryExecutor;
use Axon\ReBAC\ViewerContext;
use Axon\DataLoader\DataLoaderRegistry;
use Axon\Schema\SchemaRegistry;

/**
 * QueryCommand parses and executes a GraphQL graph query from the command line.
 */
final class QueryCommand implements Command {
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

  public function getName(): string {
    return 'query';
  }

  public function getDescription(): string {
    return 'Execute a GraphQL query against the federated object graph (axon query "<query>")';
  }

  public function execute(vec<string> $args): int {
    if (\count($args) < 1) {
      \printf("Usage: axon query \"<graphql_query>\"\n");
      return 1;
    }

    $queryStr = $args[0];
    $parseRes = QueryParser::parse($queryStr);
    if ($parseRes->isErr()) {
      \fprintf(\STDERR, "Syntax Error: %s\n", $parseRes->unwrapErr());
      return 1;
    }

    $doc = $parseRes->unwrap();
    $validRes = $this->validator->validate($doc);
    if ($validRes->isErr()) {
      \fprintf(\STDERR, "Validation Error:\n");
      foreach ($validRes->unwrapErr() as $err) {
        \fprintf(\STDERR, "  - %s\n", $err);
      }
      return 1;
    }

    $plan = $this->planner->plan($doc);
    $res = $this->executor->execute($plan, ViewerContext::system(), $this->loaders);

    \printf("%s\n", \json_encode($res->jsonSerialize(), \JSON_PRETTY_PRINT | \JSON_UNESCAPED_SLASHES));
    return 0;
  }
}
