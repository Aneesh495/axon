namespace Axon\Tests\Unit;

use Axon\ReBAC\PolicyCompiler;
use Axon\ReBAC\RewriteType;

final class TestPolicyCompiler {
  public static function run(): void {
    \printf("Running TestPolicyCompiler...\n");

    $raw = dict[
      'name' => 'folder',
      'relations' => dict[
        'owner' => dict['this' => dict[]],
        'editor' => dict[
          'union' => vec[
            dict['this' => dict[]],
            dict['computed_userset' => dict['relation' => 'owner']],
          ],
        ],
      ],
    ];

    $compRes = PolicyCompiler::compileNamespace($raw);
    if ($compRes->isErr()) {
      throw new \RuntimeException("PolicyCompiler failed: " . $compRes->unwrapErr());
    }

    $ns = $compRes->unwrap();
    if ($ns->getName() !== 'folder') {
      throw new \RuntimeException("Namespace name mismatch");
    }

    $rule = $ns->getRule('editor');
    if ($rule === null || $rule->getRewrite()->getType() !== RewriteType::UNION) {
      throw new \RuntimeException("Compiled rewrite rule mismatch for editor");
    }

    \printf("TestPolicyCompiler passed.\n");
  }
}
