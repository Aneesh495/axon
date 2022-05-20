namespace Axon\CLI;

use Axon\Schema\SchemaRegistry;

/**
 * GraphVizCommand outputs entity schemas and ReBAC relationship graphs as Mermaid or Graphviz DOT diagrams.
 */
final class GraphVizCommand implements Command {
  private SchemaRegistry $schema;

  public function __construct(SchemaRegistry $schema) {
    $this->schema = $schema;
  }

  public function getName(): string {
    return 'graphviz';
  }

  public function getDescription(): string {
    return 'Export graph schema topology as Mermaid or Graphviz DOT diagram (axon graphviz [mermaid|dot])';
  }

  public function execute(vec<string> $args): int {
    $format = \count($args) >= 1 ? \strtolower($args[0]) : 'mermaid';

    if ($format === 'dot') {
      \printf("digraph AxonSchema {\n");
      \printf("  rankdir=LR;\n");
      \printf("  node [shape=record, fontname=\"Helvetica\"];\n\n");

      foreach ($this->schema->getAllEntities() as $name => $entity) {
        $fieldsList = '';
        foreach ($entity->getFields() as $fn => $fdef) {
          $fieldsList .= $fn . '\l';
        }
        \printf("  %s [label=\"{%s|%s}\"];\n", $name, $name, $fieldsList);

        foreach ($entity->getEdges() as $en => $edge) {
          \printf("  %s -> %s [label=\"%s (%s)\"];\n", $name, $edge->getTargetEntity(), $en, $edge->getCardinality()->value);
        }
      }
      \printf("}\n");
      return 0;
    }

    // Default: Mermaid format
    \printf("classDiagram\n");
    foreach ($this->schema->getAllEntities() as $name => $entity) {
      \printf("  class %s {\n", $name);
      foreach ($entity->getFields() as $fn => $fdef) {
        \printf("    +%s %s\n", $fdef->getType()->getScalar()->value, $fn);
      }
      \printf("  }\n");

      foreach ($entity->getEdges() as $en => $edge) {
        \printf("  %s --> %s : %s\n", $name, $edge->getTargetEntity(), $en);
      }
    }

    return 0;
  }
}
