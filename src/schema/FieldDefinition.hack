namespace Axon\Schema;

use Axon\Core\Result;

/**
 * FieldDefinition encapsulates schema attributes, nullability, defaults,
 * and indexing for a single entity attribute.
 */
final class FieldDefinition {
  private string $name;
  private FieldType $type;
  private bool $isPrimary;
  private bool $isNullable;
  private bool $isUnique;
  private bool $isIndexed;
  private mixed $defaultValue;
  private string $description;

  public function __construct(
    string $name,
    FieldType $type,
    bool $isPrimary = false,
    bool $isNullable = false,
    bool $isUnique = false,
    bool $isIndexed = false,
    mixed $defaultValue = null,
    string $description = ''
  ) {
    $this->name = $name;
    $this->type = $type;
    $this->isPrimary = $isPrimary;
    $this->isNullable = $isNullable;
    $this->isUnique = $isUnique;
    $this->isIndexed = $isIndexed || $isUnique || $isPrimary;
    $this->defaultValue = $defaultValue;
    $this->description = $description;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getType(): FieldType {
    return $this->type;
  }

  public function isPrimary(): bool {
    return $this->isPrimary;
  }

  public function isNullable(): bool {
    return $this->isNullable;
  }

  public function isUnique(): bool {
    return $this->isUnique;
  }

  public function isIndexed(): bool {
    return $this->isIndexed;
  }

  public function getDefaultValue(): mixed {
    return $this->defaultValue;
  }

  public function getDescription(): string {
    return $this->description;
  }

  /**
   * Validates a field value against this definition's constraints.
   */
  public function validate(mixed $value): Result<mixed, string> {
    if ($value === null) {
      if ($this->isNullable) {
        return Result::ok(null);
      }
      if ($this->defaultValue !== null) {
        return Result::ok($this->defaultValue);
      }
      return Result::err(\sprintf('Field "%s" is non-nullable but received null', $this->name));
    }

    $coerced = $this->type->validateAndCoerce($value);
    if ($coerced->isErr()) {
      return Result::err(\sprintf('Field "%s": %s', $this->name, $coerced->unwrapErr()));
    }

    return $coerced;
  }
}
