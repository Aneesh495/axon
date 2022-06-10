namespace Axon\Query;

/**
 * QueryNormalizer transforms query ASTs into canonical, sorted representations
 * for deterministic query plan caching and APQ matching.
 */
final class QueryNormalizer {
  public static function normalize(DocumentNode $document): string {
    $op = $document->getPrimaryOperation();
    if ($op === null) {
      return '';
    }

    $out = '{';
    $out .= self::normalizeSelectionSet($op->getSelectionSet());
    $out .= '}';
    return $out;
  }

  private static function normalizeSelectionSet(SelectionSet $set): string {
    $fieldStrings = vec[];

    foreach ($set->getSelections() as $sel) {
      if ($sel is FieldNode) {
        $f = $sel as FieldNode;
        $str = $f->getName();

        $args = $f->getArguments();
        if (\count($args) > 0) {
          $str .= '(';
          $argPairs = vec[];
          foreach ($args as $k => $v) {
            $argPairs[] = $k . ':' . (string)$v;
          }
          $str .= \implode(',', $argPairs);
          $str .= ')';
        }

        if ($f->getSelectionSet() !== null) {
          $str .= '{' . self::normalizeSelectionSet($f->getSelectionSet() as nonnull) . '}';
        }

        $fieldStrings[] = $str;
      }
    }

    return \implode(' ', $fieldStrings);
  }
}
