namespace Axon\Tests\Unit;

use Axon\Reactive\LiveQueryManager;
use Axon\Reactive\EventBus;
use Axon\Reactive\ChangeEvent;
use Axon\Reactive\ChangeOp;
use Axon\Query\ExecutionResult;
use Axon\ReBAC\ViewerContext;

final class TestLiveQuery {
  public static function run(): void {
    \printf("Running TestLiveQuery...\n");

    $bus = new EventBus();
    $liveManager = new LiveQueryManager($bus);

    $deltasReceived = vec[];
    $liveManager->subscribe(
      'sub-101',
      '{ Document(id: "doc-1") { title } }',
      ViewerContext::system(),
      (ExecutionResult $res) ==> {
        $deltasReceived[] = $res;
      }
    );

    if ($liveManager->count() !== 1) {
      throw new \RuntimeException("Live query count should be 1");
    }

    // Trigger an entity mutation
    $change = new ChangeEvent('e-1', 'Document', ChangeOp::UPDATE, null, dict['id' => 'doc-1', 'title' => 'New Title'], 1, 1000);
    $bus->publish('Document.updated', $change);

    if (\count($deltasReceived) !== 1) {
      throw new \RuntimeException("Live query subscription did not receive delta notification");
    }

    // Unsubscribe
    $liveManager->unsubscribe('sub-101');
    if ($liveManager->count() !== 0) {
      throw new \RuntimeException("Live query count should be 0 after unsubscribe");
    }

    \printf("TestLiveQuery passed.\n");
  }
}
