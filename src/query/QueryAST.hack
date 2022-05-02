namespace Axon\Query;

/**
 * Operation type of a graph query document.
 */
enum OperationType: string {
  QUERY = 'QUERY';
  MUTATION = 'MUTATION';
  SUBSCRIPTION = 'SUBSCRIPTION';
}

/**
 * Abstract base class for all AST nodes in a graph query.
 */
abstract class ASTNode {
  protected int $line;
  protected int $column;

  public function __construct(int $line = 1, int $column = 1) {
    $this->line = $line;
    $this->column = $column;
  }

  public function getLine(): int {
    return $this->line;
  }

  public function getColumn(): int {
    return $this->column;
  }
}

/**
 * Literal argument passed to a field or directive.
 */
final class ArgumentNode extends ASTNode {
  private string $name;
  private mixed $value;

  public function __construct(string $name, mixed $value, int $line = 1, int $column = 1) {
    parent::__construct($line, $column);
    $this->name = $name;
    $this->value = $value;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getValue(): mixed {
    return $this->value;
  }
}

/**
 * Directive applied to a field (e.g. @include(if: $flag), @skip).
 */
final class DirectiveNode extends ASTNode {
  private string $name;
  private dict<string, mixed> $arguments;

  public function __construct(string $name, dict<string, mixed> $arguments = dict[], int $line = 1, int $column = 1) {
    parent::__construct($line, $column);
    $this->name = $name;
    $this->arguments = $arguments;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getArguments(): dict<string, mixed> {
    return $this->arguments;
  }
}

/**
 * SelectionSet containing fields or fragment spreads.
 */
final class SelectionSet extends ASTNode {
  private vec<SelectionNode> $selections;

  public function __construct(vec<SelectionNode> $selections = vec[], int $line = 1, int $column = 1) {
    parent::__construct($line, $column);
    $this->selections = $selections;
  }

  public function getSelections(): vec<SelectionNode> {
    return $this->selections;
  }

  public function addSelection(SelectionNode $node): void {
    $this->selections[] = $node;
  }
}

/**
 * Base class for items selectable inside a selection set.
 */
abstract class SelectionNode extends ASTNode {}

/**
 * Concrete field selection in a query AST.
 */
final class FieldNode extends SelectionNode {
  private string $name;
  private ?string $alias;
  private dict<string, mixed> $arguments;
  private ?SelectionSet $selectionSet;
  private vec<DirectiveNode> $directives;

  public function __construct(
    string $name,
    ?string $alias = null,
    dict<string, mixed> $arguments = dict[],
    ?SelectionSet $selectionSet = null,
    vec<DirectiveNode> $directives = vec[],
    int $line = 1,
    int $column = 1
  ) {
    parent::__construct($line, $column);
    $this->name = $name;
    $this->alias = $alias;
    $this->arguments = $arguments;
    $this->selectionSet = $selectionSet;
    $this->directives = $directives;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getAlias(): ?string {
    return $this->alias;
  }

  public function getResponseKey(): string {
    return $this->alias ?? $this->name;
  }

  public function getArguments(): dict<string, mixed> {
    return $this->arguments;
  }

  public function getSelectionSet(): ?SelectionSet {
    return $this->selectionSet;
  }

  public function getDirectives(): vec<DirectiveNode> {
    return $this->directives;
  }
}

/**
 * Root Operation definition (query, mutation, subscription).
 */
final class OperationDefinition extends ASTNode {
  private OperationType $type;
  private ?string $name;
  private SelectionSet $selectionSet;
  private dict<string, string> $variableDefinitions;

  public function __construct(
    OperationType $type,
    ?string $name,
    SelectionSet $selectionSet,
    dict<string, string> $variableDefinitions = dict[],
    int $line = 1,
    int $column = 1
  ) {
    parent::__construct($line, $column);
    $this->type = $type;
    $this->name = $name;
    $this->selectionSet = $selectionSet;
    $this->variableDefinitions = $variableDefinitions;
  }

  public function getType(): OperationType {
    return $this->type;
  }

  public function getName(): ?string {
    return $this->name;
  }

  public function getSelectionSet(): SelectionSet {
    return $this->selectionSet;
  }

  public function getVariableDefinitions(): dict<string, string> {
    return $this->variableDefinitions;
  }
}

/**
 * Root Document containing one or more operation definitions.
 */
final class DocumentNode extends ASTNode {
  private vec<OperationDefinition> $operations;

  public function __construct(vec<OperationDefinition> $operations = vec[], int $line = 1, int $column = 1) {
    parent::__construct($line, $column);
    $this->operations = $operations;
  }

  public function getOperations(): vec<OperationDefinition> {
    return $this->operations;
  }

  public function getPrimaryOperation(): ?OperationDefinition {
    return \count($this->operations) > 0 ? $this->operations[0] : null;
  }
}
