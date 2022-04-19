namespace Axon\Core;

/**
 * Hybrid Logical Clock (HLC) provides monotonic, causally consistent timestamps
 * combining physical wall-clock time with logical sequence numbers.
 *
 * It satisfies:
 * 1. e1 -> e2 implies HLC(e1) < HLC(e2) (strict causal consistency)
 * 2. |HLC(e).physical - PhysicalTime(e)| <= MaxOffset (bounded clock drift)
 */
final class HLC implements \JsonSerializable {
  private int $physical;
  private int $logical;

  public function __construct(int $physical, int $logical) {
    $this->physical = $physical;
    $this->logical = $logical;
  }

  public function getPhysical(): int {
    return $this->physical;
  }

  public function getLogical(): int {
    return $this->logical;
  }

  public function compare(HLC $other): int {
    if ($this->physical < $other->physical) {
      return -1;
    }
    if ($this->physical > $other->physical) {
      return 1;
    }
    if ($this->logical < $other->logical) {
      return -1;
    }
    if ($this->logical > $other->logical) {
      return 1;
    }
    return 0;
  }

  public function equals(HLC $other): bool {
    return $this->physical === $other->physical && $this->logical === $other->logical;
  }

  public function toString(): string {
    return \sprintf('%d:%d', $this->physical, $this->logical);
  }

  public function jsonSerialize(): dict<string, int> {
    return dict[
      'physical' => $this->physical,
      'logical' => $this->logical,
    ];
  }

  public static function parse(string $raw): Result<HLC, string> {
    $parts = \explode(':', \trim($raw));
    if (\count($parts) !== 2) {
      return Result::err('Invalid HLC string format; expected physical:logical');
    }
    $p = (int)$parts[0];
    $l = (int)$parts[1];
    return Result::ok(new HLC($p, $l));
  }
}

/**
 * State manager for a node's local Hybrid Logical Clock.
 */
final class HLCClock {
  private int $latestPhysical;
  private int $latestLogical;
  private int $maxOffsetMs;

  public function __construct(int $maxOffsetMs = 60000) {
    $this->maxOffsetMs = $maxOffsetMs;
    $this->latestPhysical = 0;
    $this->latestLogical = 0;
  }

  /**
   * Generates a new timestamp for a local event.
   */
  public function now(int $wallMs = 0): HLC {
    $pt = $wallMs > 0 ? $wallMs : (int)(\microtime(true) * 1000.0);

    if ($pt > $this->latestPhysical) {
      $this->latestPhysical = $pt;
      $this->latestLogical = 0;
    } else {
      $this->latestLogical++;
    }

    return new HLC($this->latestPhysical, $this->latestLogical);
  }

  /**
   * Updates the local clock given a received message timestamp.
   */
  public function update(HLC $received, int $wallMs = 0): Result<HLC, string> {
    $pt = $wallMs > 0 ? $wallMs : (int)(\microtime(true) * 1000.0);

    // Guard against excessive clock drift from remote message
    if ($received->getPhysical() - $pt > $this->maxOffsetMs) {
      return Result::err(\sprintf(
        'Clock skew exceeds threshold: remote=%d, local_wall=%d, max_offset=%d',
        $received->getPhysical(),
        $pt,
        $this->maxOffsetMs
      ));
    }

    $newPhysical = \max($pt, \max($this->latestPhysical, $received->getPhysical()));

    if ($newPhysical === $this->latestPhysical && $newPhysical === $received->getPhysical()) {
      $this->latestLogical = \max($this->latestLogical, $received->getLogical()) + 1;
    } else if ($newPhysical === $this->latestPhysical) {
      $this->latestLogical++;
    } else if ($newPhysical === $received->getPhysical()) {
      $this->latestLogical = $received->getLogical() + 1;
    } else {
      $this->latestLogical = 0;
    }

    $this->latestPhysical = $newPhysical;
    return Result::ok(new HLC($this->latestPhysical, $this->latestLogical));
  }
}
