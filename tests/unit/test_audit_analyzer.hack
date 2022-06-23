namespace Axon\Tests\Unit;

use Axon\Analytics\AuditAnalyzer;
use Axon\ReBAC\AuditLogger;
use Axon\ReBAC\AuditRecord;
use Axon\ReBAC\Decision;
use Axon\ReBAC\Subject;

final class TestAuditAnalyzer {
  public static function run(): void {
    \printf("Running TestAuditAnalyzer...\n");

    $logger = new AuditLogger();
    $alice = new Subject('user', 'alice');
    $mallory = new Subject('user', 'mallory');

    $logger->log(new AuditRecord(1000, $alice, 'doc', 'd-1', 'viewer', Decision::ALLOW, 150));
    $logger->log(new AuditRecord(1001, $mallory, 'doc', 'd-2', 'viewer', Decision::DENY, 200));
    $logger->log(new AuditRecord(1002, $mallory, 'doc', 'd-3', 'viewer', Decision::DENY, 210));

    $analyzer = new AuditAnalyzer($logger);
    $report = $analyzer->analyze();

    if ($report->getTotalEvaluated() !== 3) {
      throw new \RuntimeException("Expected 3 evaluated audit records");
    }
    if ($report->getDenialCount() !== 2) {
      throw new \RuntimeException("Expected 2 denials");
    }

    $topDenied = $report->getTopDenialSubjects();
    if (!\array_key_exists('user:mallory', $topDenied) || $topDenied['user:mallory'] !== 2) {
      throw new \RuntimeException("Mallory should be identified with 2 denials");
    }

    \printf("TestAuditAnalyzer passed.\n");
  }
}
