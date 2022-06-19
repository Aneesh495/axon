namespace Axon\Distributed;

use Axon\Core\CRC32;

/**
 * ConsistentHashRing implements virtual node consistent hashing for shard partitioning.
 */
final class ConsistentHashRing {
  private int $replicas;
  private vec<int> $ringTokens;
  private dict<int, string> $tokenToNode;

  public function __construct(int $replicas = 100) {
    $this->replicas = $replicas;
    $this->ringTokens = vec[];
    $this->tokenToNode = dict[];
  }

  public function addNode(string $nodeId): void {
    for ($i = 0; $i < $this->replicas; $i++) {
      $tokenKey = \sprintf('%s#vnode_%d', $nodeId, $i);
      $token = CRC32::calculate($tokenKey);
      $this->ringTokens[] = $token;
      $this->tokenToNode[$token] = $nodeId;
    }
    // Re-sort tokens along ring
    $sorted = $this->ringTokens;
    \sort(&$sorted);
    $this->ringTokens = $sorted;
  }

  public function removeNode(string $nodeId): void {
    $remaining = vec[];
    foreach ($this->ringTokens as $token) {
      if (\array_key_exists($token, $this->tokenToNode) && $this->tokenToNode[$token] === $nodeId) {
        unset($this->tokenToNode[$token]);
      } else {
        $remaining[] = $token;
      }
    }
    $this->ringTokens = $remaining;
  }

  public function getNode(string $key): ?string {
    if (\count($this->ringTokens) === 0) {
      return null;
    }

    $keyHash = CRC32::calculate($key);

    // Binary search for first token >= keyHash
    $low = 0;
    $high = \count($this->ringTokens) - 1;
    $targetIdx = 0;

    while ($low <= $high) {
      $mid = (int)(($low + $high) / 2);
      if ($this->ringTokens[$mid] >= $keyHash) {
        $targetIdx = $mid;
        $high = $mid - 1;
      } else {
        $low = $mid + 1;
      }
    }

    $chosenToken = $this->ringTokens[$targetIdx];
    return $this->tokenToNode[$chosenToken];
  }

  public function getNodeCount(): int {
    $nodes = keyset[];
    foreach ($this->tokenToNode as $n) {
      $nodes[] = $n;
    }
    return \count($nodes);
  }
}
