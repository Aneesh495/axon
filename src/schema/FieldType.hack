namespace Axon\Schema;

use Axon\Core\Result;

/**
 * Primitive and composite scalar data types supported by Axon entity fields.
 */
enum ScalarType: string {
  INT = 'INT';
  FLOAT = 'FLOAT';
  STRING = 'STRING';
  BOOL = 'BOOL';
  ID = 'ID';
  DATETIME = 'DATETIME';
  JSON = 'JSON';
  BYTES = 'BYTES';
}

/**
 * FieldType provides type validation, serialization, and casting rules.
 */
final class FieldType {
  private ScalarType $scalar;
  private ?vec<string> $allowedEnumValues;

  public function __construct(ScalarType $scalar, ?vec<string> $allowedEnumValues = null) {
    $this->scalar = $scalar;
    $this->allowedEnumValues = $allowedEnumValues;
  }

  public function getScalar(): ScalarType {
    return $this->scalar;
  }

  public function isEnum(): bool {
    return $this->allowedEnumValues !== null;
  }

  public function getAllowedEnumValues(): ?vec<string> {
    return $this->allowedEnumValues;
  }

  public static function int(): FieldType {
    return new FieldType(ScalarType::INT);
  }

  public static function float(): FieldType {
    return new FieldType(ScalarType::FLOAT);
  }

  public static function string(): FieldType {
    return new FieldType(ScalarType::STRING);
  }

  public static function bool(): FieldType {
    return new FieldType(ScalarType::BOOL);
  }

  public static function id(): FieldType {
    return new FieldType(ScalarType::ID);
  }

  public static function dateTime(): FieldType {
    return new FieldType(ScalarType::DATETIME);
  }

  public static function json(): FieldType {
    return new FieldType(ScalarType::JSON);
  }

  public static function bytes(): FieldType {
    return new FieldType(ScalarType::BYTES);
  }

  public static function enumType(vec<string> $values): FieldType {
    return new FieldType(ScalarType::STRING, $values);
  }

  /**
   * Validates and coerces a raw mixed value into the expected field type.
   */
  public function validateAndCoerce(mixed $value): Result<mixed, string> {
    if ($value === null) {
      return Result::ok(null);
    }

    if ($this->allowedEnumValues !== null) {
      if (!\is_string($value)) {
        return Result::err('Enum value must be a string');
      }
      foreach ($this->allowedEnumValues as $allowed) {
        if ($allowed === $value) {
          return Result::ok($value);
        }
      }
      return Result::err(\sprintf('Invalid enum value: %s', $value));
    }

    switch ($this->scalar) {
      case ScalarType::INT:
        if (\is_int($value)) {
          return Result::ok($value);
        }
        if (\is_numeric($value)) {
          return Result::ok((int)$value);
        }
        return Result::err('Expected integer value');

      case ScalarType::FLOAT:
        if (\is_float($value) || \is_int($value)) {
          return Result::ok((float)$value);
        }
        if (\is_numeric($value)) {
          return Result::ok((float)$value);
        }
        return Result::err('Expected floating point value');

      case ScalarType::STRING:
        if (\is_string($value)) {
          return Result::ok($value);
        }
        return Result::err('Expected string value');

      case ScalarType::BOOL:
        if (\is_bool($value)) {
          return Result::ok($value);
        }
        if ($value === 1 || $value === '1' || $value === 'true') {
          return Result::ok(true);
        }
        if ($value === 0 || $value === '0' || $value === 'false') {
          return Result::ok(false);
        }
        return Result::err('Expected boolean value');

      case ScalarType::ID:
        if (\is_string($value)) {
          return Result::ok($value);
        }
        return Result::err('Expected string identifier');

      case ScalarType::DATETIME:
        if (\is_int($value)) {
          return Result::ok($value);
        }
        if (\is_string($value)) {
          $ts = \strtotime($value);
          if ($ts !== false) {
            return Result::ok($ts);
          }
        }
        return Result::err('Expected unix epoch timestamp or ISO-8601 datetime string');

      case ScalarType::JSON:
        if (\is_array($value) || \is_dict($value) || \is_vec($value)) {
          return Result::ok($value);
        }
        if (\is_string($value)) {
          $decoded = \json_decode($value, true);
          if ($decoded !== null || $value === 'null') {
            return Result::ok($decoded);
          }
        }
        return Result::err('Expected valid JSON structured data');

      case ScalarType::BYTES:
        if (\is_string($value)) {
          return Result::ok($value);
        }
        return Result::err('Expected raw byte string');
    }
  }
}
