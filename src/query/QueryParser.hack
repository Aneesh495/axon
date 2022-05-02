namespace Axon\Query;

use Axon\Core\Result;

/**
 * Token types produced by the query lexer.
 */
enum TokenType: string {
  NAME = 'NAME';
  STRING = 'STRING';
  INT = 'INT';
  FLOAT = 'FLOAT';
  COLON = ':';
  DOLLAR = '$';
  LPAREN = '(';
  RPAREN = ')';
  LBRACE = '{';
  RBRACE = '}';
  SPREAD = '...';
  AT = '@';
  EQUALS = '=';
  EOF = 'EOF';
}

/**
 * Token representation with line and column tracking.
 */
final class Token {
  public TokenType $type;
  public string $value;
  public int $line;
  public int $column;

  public function __construct(TokenType $type, string $value, int $line, int $column) {
    $this->type = $type;
    $this->value = $value;
    $this->line = $line;
    $this->column = $column;
  }
}

/**
 * High-speed lexer for GraphQL-style query strings.
 */
final class QueryLexer {
  private string $source;
  private int $len;
  private int $pos;
  private int $line;
  private int $column;

  public function __construct(string $source) {
    $this->source = $source;
    $this->len = \strlen($source);
    $this->pos = 0;
    $this->line = 1;
    $this->column = 1;
  }

  public function tokenize(): Result<vec<Token>, string> {
    $tokens = vec[];

    while ($this->pos < $this->len) {
      $ch = $this->source[$this->pos];

      // Skip whitespace and commas
      if ($ch === ' ' || $ch === "\t" || $ch === "\r" || $ch === ',') {
        $this->pos++;
        $this->column++;
        continue;
      }

      if ($ch === "\n") {
        $this->pos++;
        $this->line++;
        $this->column = 1;
        continue;
      }

      // Skip comments starting with #
      if ($ch === '#') {
        while ($this->pos < $this->len && $this->source[$this->pos] !== "\n") {
          $this->pos++;
        }
        continue;
      }

      $startLine = $this->line;
      $startCol = $this->column;

      if ($ch === '{') {
        $tokens[] = new Token(TokenType::LBRACE, '{', $startLine, $startCol);
        $this->advance(1);
        continue;
      }
      if ($ch === '}') {
        $tokens[] = new Token(TokenType::RBRACE, '}', $startLine, $startCol);
        $this->advance(1);
        continue;
      }
      if ($ch === '(') {
        $tokens[] = new Token(TokenType::LPAREN, '(', $startLine, $startCol);
        $this->advance(1);
        continue;
      }
      if ($ch === ')') {
        $tokens[] = new Token(TokenType::RPAREN, ')', $startLine, $startCol);
        $this->advance(1);
        continue;
      }
      if ($ch === ':') {
        $tokens[] = new Token(TokenType::COLON, ':', $startLine, $startCol);
        $this->advance(1);
        continue;
      }
      if ($ch === '$') {
        $tokens[] = new Token(TokenType::DOLLAR, '$', $startLine, $startCol);
        $this->advance(1);
        continue;
      }
      if ($ch === '@') {
        $tokens[] = new Token(TokenType::AT, '@', $startLine, $startCol);
        $this->advance(1);
        continue;
      }
      if ($ch === '=') {
        $tokens[] = new Token(TokenType::EQUALS, '=', $startLine, $startCol);
        $this->advance(1);
        continue;
      }

      if ($ch === '.' && $this->pos + 2 < $this->len && $this->source[$this->pos + 1] === '.' && $this->source[$this->pos + 2] === '.') {
        $tokens[] = new Token(TokenType::SPREAD, '...', $startLine, $startCol);
        $this->advance(3);
        continue;
      }

      // Strings: "..."
      if ($ch === '"') {
        $strRes = $this->readString();
        if ($strRes->isErr()) {
          return Result::err($strRes->unwrapErr());
        }
        $tokens[] = new Token(TokenType::STRING, $strRes->unwrap(), $startLine, $startCol);
        continue;
      }

      // Numbers: int or float
      if ($ch === '-' || \ctype_digit($ch)) {
        $numToken = $this->readNumber($startLine, $startCol);
        $tokens[] = $numToken;
        continue;
      }

      // Identifiers / Names
      if (\ctype_alpha($ch) || $ch === '_') {
        $nameVal = $this->readName();
        $tokens[] = new Token(TokenType::NAME, $nameVal, $startLine, $startCol);
        continue;
      }

      return Result::err(\sprintf('Unexpected character "%s" at line %d, column %d', $ch, $this->line, $this->column));
    }

    $tokens[] = new Token(TokenType::EOF, '', $this->line, $this->column);
    return Result::ok($tokens);
  }

  private function advance(int $count): void {
    $this->pos += $count;
    $this->column += $count;
  }

  private function readString(): Result<string, string> {
    $this->advance(1); // skip opening quote
    $buf = '';

    while ($this->pos < $this->len) {
      $ch = $this->source[$this->pos];
      if ($ch === '"') {
        $this->advance(1); // skip closing quote
        return Result::ok($buf);
      }
      if ($ch === '\\') {
        $this->advance(1);
        if ($this->pos >= $this->len) {
          return Result::err('Unterminated string escape sequence');
        }
        $escaped = $this->source[$this->pos];
        if ($escaped === 'n') {
          $buf .= "\n";
        } else if ($escaped === 't') {
          $buf .= "\t";
        } else if ($escaped === 'r') {
          $buf .= "\r";
        } else {
          $buf .= $escaped;
        }
        $this->advance(1);
        continue;
      }
      $buf .= $ch;
      $this->advance(1);
    }

    return Result::err('Unterminated string literal');
  }

  private function readNumber(int $startLine, int $startCol): Token {
    $buf = '';
    $isFloat = false;

    if ($this->source[$this->pos] === '-') {
      $buf .= '-';
      $this->advance(1);
    }

    while ($this->pos < $this->len) {
      $ch = $this->source[$this->pos];
      if (\ctype_digit($ch)) {
        $buf .= $ch;
        $this->advance(1);
      } else if ($ch === '.' && !$isFloat) {
        $isFloat = true;
        $buf .= '.';
        $this->advance(1);
      } else {
        break;
      }
    }

    $type = $isFloat ? TokenType::FLOAT : TokenType::INT;
    return new Token($type, $buf, $startLine, $startCol);
  }

  private function readName(): string {
    $buf = '';
    while ($this->pos < $this->len) {
      $ch = $this->source[$this->pos];
      if (\ctype_alnum($ch) || $ch === '_') {
        $buf .= $ch;
        $this->advance(1);
      } else {
        break;
      }
    }
    return $buf;
  }
}

/**
 * QueryParser transforms raw token sequences into structured QueryAST documents.
 */
final class QueryParser {
  private vec<Token> $tokens;
  private int $idx;

  public function __construct(vec<Token> $tokens) {
    $this->tokens = $tokens;
    $this->idx = 0;
  }

  public static function parse(string $source): Result<DocumentNode, string> {
    $lexer = new QueryLexer($source);
    $tokenRes = $lexer->tokenize();
    if ($tokenRes->isErr()) {
      return Result::err($tokenRes->unwrapErr());
    }

    $parser = new QueryParser($tokenRes->unwrap());
    return $parser->parseDocument();
  }

  public function parseDocument(): Result<DocumentNode, string> {
    $operations = vec[];

    while (!$this->peek(TokenType::EOF)) {
      $opRes = $this->parseOperation();
      if ($opRes->isErr()) {
        return Result::err($opRes->unwrapErr());
      }
      $operations[] = $opRes->unwrap();
    }

    if (\count($operations) === 0) {
      return Result::err('Empty query document: no operations defined');
    }

    return Result::ok(new DocumentNode($operations));
  }

  private function parseOperation(): Result<OperationDefinition, string> {
    $type = OperationType::QUERY;
    $name = null;

    if ($this->peek(TokenType::NAME)) {
      $val = $this->currentToken()->value;
      if ($val === 'query') {
        $this->advance();
        $type = OperationType::QUERY;
      } else if ($val === 'mutation') {
        $this->advance();
        $type = OperationType::MUTATION;
      } else if ($val === 'subscription') {
        $this->advance();
        $type = OperationType::SUBSCRIPTION;
      }

      if ($this->peek(TokenType::NAME)) {
        $name = $this->currentToken()->value;
        $this->advance();
      }
    }

    $setRes = $this->parseSelectionSet();
    if ($setRes->isErr()) {
      return Result::err($setRes->unwrapErr());
    }

    return Result::ok(new OperationDefinition($type, $name, $setRes->unwrap()));
  }

  private function parseSelectionSet(): Result<SelectionSet, string> {
    if (!$this->match(TokenType::LBRACE)) {
      return Result::err(\sprintf('Expected "{" opening selection set at line %d', $this->currentToken()->line));
    }

    $selections = vec[];

    while (!$this->peek(TokenType::RBRACE) && !$this->peek(TokenType::EOF)) {
      $fieldRes = $this->parseField();
      if ($fieldRes->isErr()) {
        return Result::err($fieldRes->unwrapErr());
      }
      $selections[] = $fieldRes->unwrap();
    }

    if (!$this->match(TokenType::RBRACE)) {
      return Result::err('Expected "}" closing selection set');
    }

    return Result::ok(new SelectionSet($selections));
  }

  private function parseField(): Result<FieldNode, string> {
    if (!$this->peek(TokenType::NAME)) {
      return Result::err(\sprintf('Expected field name at line %d', $this->currentToken()->line));
    }

    $firstToken = $this->currentToken();
    $this->advance();

    $name = $firstToken->value;
    $alias = null;

    if ($this->match(TokenType::COLON)) {
      // First token was an alias
      $alias = $name;
      if (!$this->peek(TokenType::NAME)) {
        return Result::err('Expected field name following alias colon');
      }
      $name = $this->currentToken()->value;
      $this->advance();
    }

    $args = dict[];
    if ($this->match(TokenType::LPAREN)) {
      while (!$this->peek(TokenType::RPAREN) && !$this->peek(TokenType::EOF)) {
        if (!$this->peek(TokenType::NAME)) {
          return Result::err('Expected argument name');
        }
        $argName = $this->currentToken()->value;
        $this->advance();

        if (!$this->match(TokenType::COLON)) {
          return Result::err('Expected ":" after argument name');
        }

        $argVal = $this->parseValue();
        $args[$argName] = $argVal;
      }
      $this->match(TokenType::RPAREN);
    }

    $selectionSet = null;
    if ($this->peek(TokenType::LBRACE)) {
      $subRes = $this->parseSelectionSet();
      if ($subRes->isErr()) {
        return Result::err($subRes->unwrapErr());
      }
      $selectionSet = $subRes->unwrap();
    }

    return Result::ok(new FieldNode($name, $alias, $args, $selectionSet, vec[], $firstToken->line, $firstToken->column));
  }

  private function parseValue(): mixed {
    $cur = $this->currentToken();
    if ($cur->type === TokenType::STRING) {
      $this->advance();
      return $cur->value;
    }
    if ($cur->type === TokenType::INT) {
      $this->advance();
      return (int)$cur->value;
    }
    if ($cur->type === TokenType::FLOAT) {
      $this->advance();
      return (float)$cur->value;
    }
    if ($cur->type === TokenType::NAME) {
      $this->advance();
      if ($cur->value === 'true') {
        return true;
      }
      if ($cur->value === 'false') {
        return false;
      }
      if ($cur->value === 'null') {
        return null;
      }
      return $cur->value;
    }
    $this->advance();
    return $cur->value;
  }

  private function currentToken(): Token {
    return $this->tokens[$this->idx];
  }

  private function peek(TokenType $type): bool {
    return $this->currentToken()->type === $type;
  }

  private function match(TokenType $type): bool {
    if ($this->peek($type)) {
      $this->advance();
      return true;
    }
    return false;
  }

  private function advance(): void {
    if ($this->idx < \count($this->tokens) - 1) {
      $this->idx++;
    }
  }
}
