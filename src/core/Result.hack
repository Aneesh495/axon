namespace Axon\Core;

/**
 * Result represents either success (Ok) containing a value of type TVal,
 * or failure (Err) containing an error of type TErr.
 */
final class Result<TVal, TErr> {
  private bool $isOk;
  private ?TVal $val;
  private ?TErr $err;

  private function __construct(bool $isOk, ?TVal $val, ?TErr $err) {
    $this->isOk = $isOk;
    $this->val = $val;
    $this->err = $err;
  }

  public static function ok(TVal $val): Result<TVal, TErr> {
    return new Result<TVal, TErr>(true, $val, null);
  }

  public static function err(TErr $err): Result<TVal, TErr> {
    return new Result<TVal, TErr>(false, null, $err);
  }

  public function isOk(): bool {
    return $this->isOk;
  }

  public function isErr(): bool {
    return !$this->isOk;
  }

  public function unwrap(): TVal {
    if (!$this->isOk) {
      $errStr = \is_string($this->err) ? $this->err : 'Unknown error';
      throw new \RuntimeException('Called unwrap on Err Result: ' . $errStr);
    }
    return $this->val as nonnull;
  }

  public function unwrapErr(): TErr {
    if ($this->isOk) {
      throw new \RuntimeException('Called unwrapErr on Ok Result');
    }
    return $this->err as nonnull;
  }

  public function unwrapOr(TVal $fallback): TVal {
    if ($this->isOk) {
      return $this->val as nonnull;
    }
    return $fallback;
  }

  public function map<TNew>((function(TVal): TNew) $fn): Result<TNew, TErr> {
    if ($this->isOk) {
      return Result::ok($fn($this->val as nonnull));
    }
    return Result::err($this->err as nonnull);
  }

  public function flatMap<TNew>((function(TVal): Result<TNew, TErr>) $fn): Result<TNew, TErr> {
    if ($this->isOk) {
      return $fn($this->val as nonnull);
    }
    return Result::err($this->err as nonnull);
  }

  public function match<TOut>(
    (function(TVal): TOut) $onOk,
    (function(TErr): TOut) $onErr
  ): TOut {
    if ($this->isOk) {
      return $onOk($this->val as nonnull);
    }
    return $onErr($this->err as nonnull);
  }
}

/**
 * Option represents an optional value: either Some(T) or None.
 */
final class Option<T> {
  private bool $isSome;
  private ?T $val;

  private function __construct(bool $isSome, ?T $val) {
    $this->isSome = $isSome;
    $this->val = $val;
  }

  public static function some(T $val): Option<T> {
    return new Option<T>(true, $val);
  }

  public static function none(): Option<T> {
    return new Option<T>(false, null);
  }

  public function isSome(): bool {
    return $this->isSome;
  }

  public function isNone(): bool {
    return !$this->isSome;
  }

  public function unwrap(): T {
    if (!$this->isSome) {
      throw new \RuntimeException('Called unwrap on None Option');
    }
    return $this->val as nonnull;
  }

  public function unwrapOr(T $fallback): T {
    if ($this->isSome) {
      return $this->val as nonnull;
    }
    return $fallback;
  }

  public function map<TNew>((function(T): TNew) $fn): Option<TNew> {
    if ($this->isSome) {
      return Option::some($fn($this->val as nonnull));
    }
    return Option::none();
  }
}
