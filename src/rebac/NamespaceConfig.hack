namespace Axon\ReBAC;

use Axon\Core\Result;

/**
 * RelationRule associates a relation or permission name with its UsersetRewrite logic.
 */
final class RelationRule {
  private string $name;
  private UsersetRewrite $rewrite;

  public function __construct(string $name, UsersetRewrite $rewrite) {
    $this->name = $name;
    $this->rewrite = $rewrite;
  }

  public function getName(): string {
    return $this->name;
  }

  public function getRewrite(): UsersetRewrite {
    return $this->rewrite;
  }
}

/**
 * NamespaceConfig defines all valid relations and authorization rules for an entity type.
 */
final class NamespaceConfig {
  private string $name;
  private dict<string, RelationRule> $rules;

  public function __construct(string $name, dict<string, RelationRule> $rules = dict[]) {
    $this->name = $name;
    $this->rules = $rules;
  }

  public function getName(): string {
    return $this->name;
  }

  public function addRule(RelationRule $rule): void {
    $this->rules[$rule->getName()] = $rule;
  }

  public function getRule(string $relation): ?RelationRule {
    return \array_key_exists($relation, $this->rules) ? $this->rules[$relation] : null;
  }

  public function hasRelation(string $relation): bool {
    return \array_key_exists($relation, $this->rules);
  }

  public function getRules(): dict<string, RelationRule> {
    return $this->rules;
  }
}

/**
 * PolicyRegistry manages the active collection of ReBAC namespace configurations.
 */
final class PolicyRegistry {
  private dict<string, NamespaceConfig> $namespaces;

  public function __construct() {
    $this->namespaces = dict[];
  }

  public function registerNamespace(NamespaceConfig $config): void {
    $this->namespaces[$config->getName()] = $config;
  }

  public function getNamespace(string $name): ?NamespaceConfig {
    return \array_key_exists($name, $this->namespaces) ? $this->namespaces[$name] : null;
  }

  public function hasNamespace(string $name): bool {
    return \array_key_exists($name, $this->namespaces);
  }

  public function getAllNamespaces(): dict<string, NamespaceConfig> {
    return $this->namespaces;
  }
}
