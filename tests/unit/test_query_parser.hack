namespace Axon\Tests\Unit;

use Axon\Query\QueryParser;
use Axon\Query\FieldNode;

final class TestQueryParser {
  public static function run(): void {
    \printf("Running TestQueryParser...\n");

    $query = 'query GetDoc { myDoc: Document(id: "doc-1", draft: false) { title content owner { username } } }';
    $parseRes = QueryParser::parse($query);

    if ($parseRes->isErr()) {
      throw new \RuntimeException("Query parsing failed: " . $parseRes->unwrapErr());
    }

    $doc = $parseRes->unwrap();
    $op = $doc->getPrimaryOperation();
    if ($op === null) {
      throw new \RuntimeException("Operation definition missing");
    }

    $selections = $op->getSelectionSet()->getSelections();
    if (\count($selections) !== 1) {
      throw new \RuntimeException("Expected 1 root selection");
    }

    $rootField = $selections[0] as FieldNode;
    if ($rootField->getName() !== 'Document') {
      throw new \RuntimeException("Expected field name Document");
    }
    if ($rootField->getAlias() !== 'myDoc') {
      throw new \RuntimeException("Expected alias myDoc");
    }
    if ($rootField->getResponseKey() !== 'myDoc') {
      throw new \RuntimeException("Expected response key myDoc");
    }

    $args = $rootField->getArguments();
    if (!\array_key_exists('id', $args) || $args['id'] !== 'doc-1') {
      throw new \RuntimeException("Argument id mismatch");
    }
    if (!\array_key_exists('draft', $args) || $args['draft'] !== false) {
      throw new \RuntimeException("Argument draft mismatch");
    }

    \printf("TestQueryParser passed.\n");
  }
}
