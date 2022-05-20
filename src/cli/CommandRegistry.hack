namespace Axon\CLI;

use Axon\Core\Result;

/**
 * Command interface for all Axon CLI commands.
 */
interface Command {
  public function getName(): string;
  public function getDescription(): string;
  public function execute(vec<string> $args): int;
}

/**
 * CommandRegistry coordinates command dispatching and user help generation.
 */
final class CommandRegistry {
  private dict<string, Command> $commands;

  public function __construct() {
    $this->commands = dict[];
  }

  public function register(Command $cmd): void {
    $this->commands[$cmd->getName()] = $cmd;
  }

  public function run(vec<string> $argv): int {
    if (\count($argv) < 2) {
      $this->printUsage();
      return 1;
    }

    $cmdName = $argv[1];
    if ($cmdName === '--help' || $cmdName === '-h') {
      $this->printUsage();
      return 0;
    }

    if (!\array_key_exists($cmdName, $this->commands)) {
      \fwrite(\STDERR, \sprintf("Error: Unknown command \"%s\"\n\n", $cmdName));
      $this->printUsage();
      return 1;
    }

    $cmd = $this->commands[$cmdName];
    $args = \array_slice($argv, 2);
    return $cmd->execute(vec($args));
  }

  public function printUsage(): void {
    \printf("Axon: Distributed Federated Graph Execution Engine & ReBAC Hypervisor\n\n");
    \printf("Usage:\n  axon <command> [arguments]\n\n");
    \printf("Available Commands:\n");

    foreach ($this->commands as $name => $cmd) {
      \printf("  %-14s %s\n", $name, $cmd->getDescription());
    }
    \printf("\nRun 'axon <command> --help' for details on specific arguments.\n");
  }
}
