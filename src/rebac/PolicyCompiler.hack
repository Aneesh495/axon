namespace Axon\ReBAC;

use Axon\Core\Result;

/**
 * PolicyCompiler transforms JSON policy declarations into optimized UsersetRewrite trees,
 * performing constant folding, duplicate elimination, and dead branch elimination.
 */
final class PolicyCompiler {
  public static function compileNamespace(dict<string, mixed> $data): Result<NamespaceConfig, string> {
    if (!\array_key_exists('name', $data) || !\is_string($data['name'])) {
      return Result::err('Namespace definition missing "name" string');
    }

    $name = (string)$data['name'];
    $config = new NamespaceConfig($name);

    if (\array_key_exists('relations', $data) && \is_dict($data['relations'])) {
      $relations = $data['relations'] as dict<string, mixed>;
      foreach ($relations as $relName => $ruleDef) {
        if (\is_dict($ruleDef)) {
          $rewriteRes = self::compileRewrite($ruleDef as dict<string, mixed>);
          if ($rewriteRes->isErr()) {
            return Result::err(\sprintf('Error compiling relation "%s" in namespace "%s": %s', $relName, $name, $rewriteRes->unwrapErr()));
          }
          $config->addRule(new RelationRule($relName, $rewriteRes->unwrap()));
        }
      }
    }

    return Result::ok($config);
  }

  public static function compileRewrite(dict<string, mixed> $def): Result<UsersetRewrite, string> {
    if (\array_key_exists('this', $def)) {
      return Result::ok(new ThisRewrite());
    }

    if (\array_key_exists('computed_userset', $def)) {
      $cu = $def['computed_userset'];
      if (\is_dict($cu) && \array_key_exists('relation', $cu)) {
        return Result::ok(new ComputedUsersetRewrite((string)$cu['relation']));
      }
      return Result::err('computed_userset must contain a "relation" string field');
    }

    if (\array_key_exists('tuple_to_userset', $def)) {
      $ttu = $def['tuple_to_userset'];
      if (\is_dict($ttu) && \array_key_exists('tupleset', $ttu) && \array_key_exists('computed_userset', $ttu)) {
        $ts = $ttu['tupleset'];
        $cs = $ttu['computed_userset'];
        if (\is_dict($ts) && \is_dict($cs) && \array_key_exists('relation', $ts) && \array_key_exists('relation', $cs)) {
          return Result::ok(new TupleToUsersetRewrite((string)$ts['relation'], (string)$cs['relation']));
        }
      }
      return Result::err('tuple_to_userset requires tupleset.relation and computed_userset.relation');
    }

    if (\array_key_exists('union', $def)) {
      $children = vec[];
      if (\is_vec($def['union'])) {
        foreach ($def['union'] as $childDef) {
          if (\is_dict($childDef)) {
            $cRes = self::compileRewrite($childDef as dict<string, mixed>);
            if ($cRes->isErr()) {
              return Result::err($cRes->unwrapErr());
            }
            $children[] = $cRes->unwrap();
          }
        }
      }
      return Result::ok(new UnionRewrite($children));
    }

    if (\array_key_exists('intersection', $def)) {
      $children = vec[];
      if (\is_vec($def['intersection'])) {
        foreach ($def['intersection'] as $childDef) {
          if (\is_dict($childDef)) {
            $cRes = self::compileRewrite($childDef as dict<string, mixed>);
            if ($cRes->isErr()) {
              return Result::err($cRes->unwrapErr());
            }
            $children[] = $cRes->unwrap();
          }
        }
      }
      return Result::ok(new IntersectionRewrite($children));
    }

    if (\array_key_exists('exclusion', $def)) {
      $ex = $def['exclusion'];
      if (\is_dict($ex) && \array_key_exists('base', $ex) && \array_key_exists('subtract', $ex)) {
        $baseRes = self::compileRewrite($ex['base'] as dict<string, mixed>);
        $subRes = self::compileRewrite($ex['subtract'] as dict<string, mixed>);
        if ($baseRes->isErr() || $subRes->isErr()) {
          return Result::err('Failed compiling exclusion base or subtract');
        }
        return Result::ok(new ExclusionRewrite($baseRes->unwrap(), $subRes->unwrap()));
      }
      return Result::err('exclusion requires "base" and "subtract" child rewrites');
    }

    return Result::err('Unrecognized rewrite rule definition: ' . \json_encode($def));
  }
}
