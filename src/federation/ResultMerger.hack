namespace Axon\Federation;

/**
 * ResultMerger deeply stitches responses from multiple subgraphs into a unified tree.
 */
final class ResultMerger {
  /**
   * Merges multiple JSON response dictionaries recursively.
   */
  public static function merge(vec<dict<string, mixed>> $responses): dict<string, mixed> {
    $merged = dict[];

    foreach ($responses as $resp) {
      $data = \array_key_exists('data', $resp) && \is_dict($resp['data'])
        ? $resp['data'] as dict<string, mixed>
        : $resp;

      foreach ($data as $k => $v) {
        if (!\array_key_exists($k, $merged)) {
          $merged[$k] = $v;
        } else if (\is_dict($merged[$k]) && \is_dict($v)) {
          $subList = vec[$merged[$k] as dict<string, mixed>, $v as dict<string, mixed>];
          $merged[$k] = self::merge($subList);
        } else {
          // Scalar overwrite with latest non-null value
          if ($v !== null) {
            $merged[$k] = $v;
          }
        }
      }
    }

    return $merged;
  }
}
