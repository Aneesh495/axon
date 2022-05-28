namespace Axon\Tests\Unit;

use Axon\Reactive\EventBus;
use Axon\Reactive\ChangeEvent;
use Axon\Reactive\ChangeOp;

final class TestEventBus {
  public static function run(): void {
    \printf("Running TestEventBus...\n");

    $bus = new EventBus();
    $specificReceived = vec[];
    $wildcardReceived = vec[];

    $bus->subscribe('document.created', (ChangeEvent $e) ==> {
      $specificReceived[] = $e;
    });

    $bus->subscribe('document.*', (ChangeEvent $e) ==> {
      $wildcardReceived[] = $e;
    });

    $evt = new ChangeEvent('evt-1', 'Document', ChangeOp::INSERT, null, dict['id' => 'doc-1'], 1, 1000);
    $bus->publish('document.created', $evt);

    if (\count($specificReceived) !== 1) {
      throw new \RuntimeException("Specific subscriber did not receive event");
    }
    if (\count($wildcardReceived) !== 1) {
      throw new \RuntimeException("Wildcard subscriber did not receive event");
    }

    $evtUpdate = new ChangeEvent('evt-2', 'Document', ChangeOp::UPDATE, null, dict['id' => 'doc-1'], 2, 1005);
    $bus->publish('document.updated', $evtUpdate);

    if (\count($specificReceived) !== 1) {
      throw new \RuntimeException("Specific subscriber received non-matching event");
    }
    if (\count($wildcardReceived) !== 2) {
      throw new \RuntimeException("Wildcard subscriber should have received second event");
    }

    \printf("TestEventBus passed.\n");
  }
}
