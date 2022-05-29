namespace Axon\Tests\Integration;

use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;
use Axon\ReBAC\Subject;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\PolicyRegistry;
use Axon\ReBAC\NamespaceConfig;
use Axon\ReBAC\RelationRule;
use Axon\ReBAC\UnionRewrite;
use Axon\ReBAC\ThisRewrite;
use Axon\ReBAC\ComputedUsersetRewrite;
use Axon\ReBAC\TupleToUsersetRewrite;

final class TestE2EEnterpriseRBAC {
  public static function run(): void {
    \printf("Running TestE2EEnterpriseRBAC...\n");

    $store = new MemoryTupleStore();
    $policies = new PolicyRegistry();

    // 1. Organization namespace:
    // admin: this
    // member: this | admin
    $orgNs = new NamespaceConfig('organization');
    $orgNs->addRule(new RelationRule('admin', new ThisRewrite()));
    $orgNs->addRule(new RelationRule('member', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('admin'),
    ])));
    $policies->registerNamespace($orgNs);

    // 2. Workspace namespace:
    // parent_org: this
    // owner: this
    // editor: this | owner
    // viewer: this | editor | parent_org.member
    $wsNs = new NamespaceConfig('workspace');
    $wsNs->addRule(new RelationRule('parent_org', new ThisRewrite()));
    $wsNs->addRule(new RelationRule('owner', new ThisRewrite()));
    $wsNs->addRule(new RelationRule('editor', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('owner'),
    ])));
    $wsNs->addRule(new RelationRule('viewer', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('editor'),
      new TupleToUsersetRewrite('parent_org', 'member'),
    ])));
    $policies->registerNamespace($wsNs);

    // 3. Document namespace:
    // parent_workspace: this
    // owner: this
    // editor: this | owner
    // viewer: this | editor | parent_workspace.viewer
    $docNs = new NamespaceConfig('document');
    $docNs->addRule(new RelationRule('parent_workspace', new ThisRewrite()));
    $docNs->addRule(new RelationRule('owner', new ThisRewrite()));
    $docNs->addRule(new RelationRule('editor', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('owner'),
    ])));
    $docNs->addRule(new RelationRule('viewer', new UnionRewrite(vec[
      new ThisRewrite(),
      new ComputedUsersetRewrite('editor'),
      new TupleToUsersetRewrite('parent_workspace', 'viewer'),
    ])));
    $policies->registerNamespace($docNs);

    $checker = new CheckEngine($policies, $store);

    $alice = new Subject('user', 'usr-alice');
    $bob = new Subject('user', 'usr-bob');
    $externalAuditor = new Subject('user', 'usr-auditor');

    // Alice is org admin
    $store->insert(new RelationTuple('organization', 'org-1', 'admin', $alice));

    // Bob is org member
    $store->insert(new RelationTuple('organization', 'org-1', 'member', $bob));

    // workspace-infra belongs to org-1
    $store->insert(new RelationTuple('workspace', 'ws-infra', 'parent_org', new Subject('organization', 'org-1')));

    // doc-runbook belongs to workspace-infra
    $store->insert(new RelationTuple('document', 'doc-runbook', 'parent_workspace', new Subject('workspace', 'ws-infra')));

    // Assert: Alice (org admin) has viewer permission on doc-runbook via transitive inheritance
    $reqAlice = new CheckRequest('document', 'doc-runbook', 'viewer', $alice);
    if (!$checker->check($reqAlice)->isAllowed()) {
      throw new \RuntimeException("Alice (org admin) should inherit viewer on doc-runbook");
    }

    // Assert: Bob (org member) has viewer permission on doc-runbook
    $reqBob = new CheckRequest('document', 'doc-runbook', 'viewer', $bob);
    if (!$checker->check($reqBob)->isAllowed()) {
      throw new \RuntimeException("Bob (org member) should inherit viewer on doc-runbook");
    }

    // Assert: Bob does NOT have editor permission on doc-runbook
    $reqBobEdit = new CheckRequest('document', 'doc-runbook', 'editor', $bob);
    if ($checker->check($reqBobEdit)->isAllowed()) {
      throw new \RuntimeException("Bob should NOT have editor permission on doc-runbook");
    }

    // Assert: External auditor has no access
    $reqAuditor = new CheckRequest('document', 'doc-runbook', 'viewer', $externalAuditor);
    if ($checker->check($reqAuditor)->isAllowed()) {
      throw new \RuntimeException("External auditor must not have access");
    }

    \printf("TestE2EEnterpriseRBAC passed.\n");
  }
}
