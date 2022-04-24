namespace Axon\ReBAC;

use Axon\Core\Result;

/**
 * Subject represents the target actor or userset in a relation tuple.
 * It can be a concrete subject (e.g., user:alice) or a userset indirection
 * (e.g., group:engineering#member).
 */
final class Subject {
  private string $namespace;
  private string $id;
  private ?string $relation;

  public function __construct(string $namespace, string $id, ?string $relation = null) {
    $this->namespace = $namespace;
    $this->id = $id;
    $this->relation = $relation;
  }

  public function getNamespace(): string {
    return $this->namespace;
  }

  public function getId(): string {
    return $this->id;
  }

  public function getRelation(): ?string {
    return $this->relation;
  }

  public function isUserset(): bool {
    return $this->relation !== null;
  }

  public function toString(): string {
    if ($this->relation !== null) {
      return \sprintf('%s:%s#%s', $this->namespace, $this->id, $this->relation);
    }
    return \sprintf('%s:%s', $this->namespace, $this->id);
  }

  public function equals(Subject $other): bool {
    return $this->namespace === $other->namespace &&
           $this->id === $other->id &&
           $this->relation === $other->relation;
  }

  public static function parse(string $raw): Result<Subject, string> {
    $trimmed = \trim($raw);
    $hashPos = \strpos($trimmed, '#');

    $relation = null;
    $target = $trimmed;
    if ($hashPos !== false) {
      $relation = \substr($trimmed, $hashPos + 1);
      $target = \substr($trimmed, 0, $hashPos);
    }

    $colonPos = \strpos($target, ':');
    if ($colonPos === false) {
      return Result::err(\sprintf('Invalid subject format "%s"; expected namespace:id', $raw));
    }

    $ns = \substr($target, 0, $colonPos);
    $id = \substr($target, $colonPos + 1);

    if ($ns === '' || $id === '') {
      return Result::err(\sprintf('Empty namespace or id in subject "%s"', $raw));
    }

    return Result::ok(new Subject($ns, $id, $relation));
  }
}

/**
 * RelationTuple represents an atomic Zanzibar assertion:
 * (namespace:object_id)#relation@subject
 */
final class RelationTuple {
  private string $namespace;
  private string $objectId;
  private string $relation;
  private Subject $subject;

  public function __construct(
    string $namespace,
    string $objectId,
    string $relation,
    Subject $subject
  ) {
    $this->namespace = $namespace;
    $this->objectId = $objectId;
    $this->relation = $relation;
    $this->subject = $subject;
  }

  public function getNamespace(): string {
    return $this->namespace;
  }

  public function getObjectId(): string {
    return $this->objectId;
  }

  public function getRelation(): string {
    return $this->relation;
  }

  public function getSubject(): Subject {
    return $this->subject;
  }

  public function toString(): string {
    return \sprintf(
      '%s:%s#%s@%s',
      $this->namespace,
      $this->objectId,
      $this->relation,
      $this->subject->toString()
    );
  }

  public function equals(RelationTuple $other): bool {
    return $this->namespace === $other->namespace &&
           $this->objectId === $other->objectId &&
           $this->relation === $other->relation &&
           $this->subject->equals($other->subject);
  }

  public static function parse(string $raw): Result<RelationTuple, string> {
    $trimmed = \trim($raw);
    $atPos = \strpos($trimmed, '@');
    if ($atPos === false) {
      return Result::err(\sprintf('Missing "@" delimiter in relation tuple: %s', $raw));
    }

    $left = \substr($trimmed, 0, $atPos);
    $right = \substr($trimmed, $atPos + 1);

    $hashPos = \strpos($left, '#');
    if ($hashPos === false) {
      return Result::err(\sprintf('Missing "#" delimiter in relation tuple object part: %s', $raw));
    }

    $objectPart = \substr($left, 0, $hashPos);
    $relation = \substr($left, $hashPos + 1);

    $colonPos = \strpos($objectPart, ':');
    if ($colonPos === false) {
      return Result::err(\sprintf('Missing ":" in object part: %s', $raw));
    }

    $ns = \substr($objectPart, 0, $colonPos);
    $objId = \substr($objectPart, $colonPos + 1);

    $subjectResult = Subject::parse($right);
    if ($subjectResult->isErr()) {
      return Result::err($subjectResult->unwrapErr());
    }

    return Result::ok(new RelationTuple($ns, $objId, $relation, $subjectResult->unwrap()));
  }
}
