namespace Axon\Distributed;

/**
 * RaftLogEntry represents an entry in the replicated consensus log.
 */
final class RaftLogEntry implements \JsonSerializable {
  private int $index;
  private int $term;
  private string $command;

  public function __construct(int $index, int $term, string $command) {
    $this->index = $index;
    $this->term = $term;
    $this->command = $command;
  }

  public function getIndex(): int {
    return $this->index;
  }

  public function getTerm(): int {
    return $this->term;
  }

  public function getCommand(): string {
    return $this->command;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'index' => $this->index,
      'term' => $this->term,
      'command' => $this->command,
    ];
  }
}

/**
 * RaftLog manages the replicated state machine log.
 */
final class RaftLog {
  private vec<RaftLogEntry> $entries;
  private int $commitIndex;
  private int $lastApplied;

  public function __construct() {
    $this->entries = vec[];
    $this->commitIndex = 0;
    $this->lastApplied = 0;
  }

  public function append(int $term, string $command): int {
    $nextIndex = \count($this->entries) + 1;
    $entry = new RaftLogEntry($nextIndex, $term, $command);
    $this->entries[] = $entry;
    return $nextIndex;
  }

  public function getEntry(int $index): ?RaftLogEntry {
    $idx = $index - 1;
    if ($idx >= 0 && $idx < \count($this->entries)) {
      return $this->entries[$idx];
    }
    return null;
  }

  public function commitTo(int $targetIndex): void {
    if ($targetIndex <= \count($this->entries)) {
      $this->commitIndex = \max($this->commitIndex, $targetIndex);
    }
  }

  public function getCommitIndex(): int {
    return $this->commitIndex;
  }

  public function getLastLogIndex(): int {
    return \count($this->entries);
  }

  public function getLastLogTerm(): int {
    $count = \count($this->entries);
    return $count > 0 ? $this->entries[$count - 1]->getTerm() : 0;
  }
}
