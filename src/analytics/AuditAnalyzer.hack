namespace Axon\Analytics;

use Axon\ReBAC\AuditLogger;
use Axon\ReBAC\Decision;

/**
 * AccessAnomalyReport records suspicious spikes in authorization denials or resource scraping.
 */
final class AccessAnomalyReport implements \JsonSerializable {
  private int $totalEvaluated;
  private int $denialCount;
  private float $denialRate;
  private dict<string, int> $topDenialSubjects;

  public function __construct(
    int $totalEvaluated,
    int $denialCount,
    float $denialRate,
    dict<string, int> $topDenialSubjects
  ) {
    $this->totalEvaluated = $totalEvaluated;
    $this->denialCount = $denialCount;
    $this->denialRate = $denialRate;
    $this->topDenialSubjects = $topDenialSubjects;
  }

  public function getTotalEvaluated(): int {
    return $this->totalEvaluated;
  }

  public function getDenialCount(): int {
    return $this->denialCount;
  }

  public function getDenialRate(): float {
    return $this->denialRate;
  }

  public function getTopDenialSubjects(): dict<string, int> {
    return $this->topDenialSubjects;
  }

  public function jsonSerialize(): dict<string, mixed> {
    return dict[
      'total' => $this->totalEvaluated,
      'denials' => $this->denialCount,
      'denial_rate' => $this->denialRate,
      'top_denied' => $this->topDenialSubjects,
    ];
  }
}

/**
 * AuditAnalyzer evaluates access patterns and identifies potential security anomalies.
 */
final class AuditAnalyzer {
  private AuditLogger $logger;

  public function __construct(AuditLogger $logger) {
    $this->logger = $logger;
  }

  public function analyze(int limit = 1000): AccessAnomalyReport {
    $records = $this->logger->getRecentRecords($limit);
    $total = \count($records);
    if ($total === 0) {
      return new AccessAnomalyReport(0, 0, 0.0, dict[]);
    }

    $denials = 0;
    $deniedSubjects = dict[];

    foreach ($records as $r) {
      if ($r->getDecision() === Decision::DENY) {
        $denials++;
        $sub = $r->getActor()->toString();
        if (!\array_key_exists($sub, $deniedSubjects)) {
          $deniedSubjects[$sub] = 0;
        }
        $deniedSubjects[$sub]++;
      }
    }

    $rate = (float)$denials / (float)$total;
    return new AccessAnomalyReport($total, $denials, $rate, $deniedSubjects);
  }
}
