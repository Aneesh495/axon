namespace Axon\CLI;

use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;
use Axon\ReBAC\Subject;

/**
 * CheckCommand evaluates permission reachability for a subject on an object.
 */
final class CheckCommand implements Command {
  private CheckEngine $checker;

  public function __construct(CheckEngine $checker) {
    $this->checker = $checker;
  }

  public function getName(): string {
    return 'check';
  }

  public function getDescription(): string {
    return 'Evaluate ReBAC permission reachability (axon check <namespace> <object_id> <permission> <subject>)';
  }

  public function execute(vec<string> $args): int {
    if (\count($args) < 4) {
      \printf("Usage: axon check <namespace> <object_id> <permission> <subject>\n");
      \printf("Example: axon check document doc-101 viewer user:alice\n");
      return 1;
    }

    $ns = $args[0];
    $objId = $args[1];
    $perm = $args[2];
    $subjectRaw = $args[3];

    $subRes = Subject::parse($subjectRaw);
    if ($subRes->isErr()) {
      \fprintf(\STDERR, "Error parsing subject: %s\n", $subRes->unwrapErr());
      return 1;
    }

    $req = new CheckRequest($ns, $objId, $perm, $subRes->unwrap());
    $resp = $this->checker->check($req);

    if ($resp->isAllowed()) {
      \printf("DECISION: ALLOW (evaluation depth: %d)\n", $resp->getDepth());
      return 0;
    } else {
      \printf("DECISION: DENY (evaluation depth: %d)\n", $resp->getDepth());
      return 2;
    }
  }
}
