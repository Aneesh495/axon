namespace Axon\Tests\Unit;

use Axon\Distributed\RaftLog;

final class TestRaftLog {
  public static function run(): void {
    \printf("Running TestRaftLog...\n");

    $log = new RaftLog();

    $i1 = $log->append(1, 'SET doc-1 {"title":"First"}');
    $i2 = $log->append(1, 'SET doc-2 {"title":"Second"}');
    $i3 = $log->append(2, 'SET doc-3 {"title":"Third"}');

    if ($i1 !== 1 || $i2 !== 2 || $i3 !== 3) {
      throw new \RuntimeException("Raft log indices should be 1-indexed monotonic");
    }

    if ($log->getLastLogIndex() !== 3 || $log->getLastLogTerm() !== 2) {
      throw new \RuntimeException("Last log index/term mismatch");
    }

    $log->commitTo(2);
    if ($log->getCommitIndex() !== 2) {
      throw new \RuntimeException("Commit index mismatch");
    }

    $entry = $log->getEntry(2);
    if ($entry === null || $entry->getCommand() !== 'SET doc-2 {"title":"Second"}') {
      throw new \RuntimeException("Raft entry lookup failed");
    }

    \printf("TestRaftLog passed.\n");
  }
}
