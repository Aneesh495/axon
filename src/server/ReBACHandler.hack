namespace Axon\Server;

use Axon\ReBAC\CheckEngine;
use Axon\ReBAC\CheckRequest;
use Axon\ReBAC\ExpandEngine;
use Axon\ReBAC\RelationTuple;
use Axon\ReBAC\MemoryTupleStore;
use Axon\ReBAC\Subject;

/**
 * ReBACHandler implements REST endpoints for Zanzibar-style access checks, expansions, and tuple writes.
 */
final class ReBACHandler {
  private CheckEngine $checker;
  private ExpandEngine $expander;
  private MemoryTupleStore $store;

  public function __construct(
    CheckEngine $checker,
    ExpandEngine $expander,
    MemoryTupleStore $store
  ) {
    $this->checker = $checker;
    $this->expander = $expander;
    $this->store = $store;
  }

  public function handleCheck(HttpRequest $request): HttpResponse {
    $body = $request->parseJsonBody();
    if ($body === null) {
      return HttpResponse::error('Expected JSON request body', 400);
    }

    $ns = (string)($body['namespace'] ?? '');
    $objId = (string)($body['object_id'] ?? '');
    $perm = (string)($body['permission'] ?? '');
    $subjectRaw = (string)($body['subject'] ?? '');

    if ($ns === '' || $objId === '' || $perm === '' || $subjectRaw === '') {
      return HttpResponse::error('Missing required fields: namespace, object_id, permission, subject', 400);
    }

    $subRes = Subject::parse($subjectRaw);
    if ($subRes->isErr()) {
      return HttpResponse::error($subRes->unwrapErr(), 400);
    }

    $req = new CheckRequest($ns, $objId, $perm, $subRes->unwrap());
    $resp = $this->checker->check($req);

    return HttpResponse::json(dict[
      'allowed' => $resp->isAllowed(),
      'depth' => $resp->getDepth(),
      'trace' => $resp->getTrace(),
    ]);
  }

  public function handleExpand(HttpRequest $request): HttpResponse {
    $body = $request->parseJsonBody();
    if ($body === null) {
      return HttpResponse::error('Expected JSON request body', 400);
    }

    $ns = (string)($body['namespace'] ?? '');
    $objId = (string)($body['object_id'] ?? '');
    $relation = (string)($body['relation'] ?? '');

    if ($ns === '' || $objId === '' || $relation === '') {
      return HttpResponse::error('Missing required fields: namespace, object_id, relation', 400);
    }

    $tree = $this->expander->expand($ns, $objId, $relation);
    return HttpResponse::json(dict[
      'type' => $tree->getType()->value,
      'children_count' => \count($tree->getChildren()),
    ]);
  }

  public function handleWrite(HttpRequest $request): HttpResponse {
    $body = $request->parseJsonBody();
    if ($body === null || !\array_key_exists('tuple', $body)) {
      return HttpResponse::error('Missing "tuple" string in request body', 400);
    }

    $tupleStr = (string)$body['tuple'];
    $parseRes = RelationTuple::parse($tupleStr);
    if ($parseRes->isErr()) {
      return HttpResponse::error($parseRes->unwrapErr(), 400);
    }

    $tuple = $parseRes->unwrap();
    $this->store->insert($tuple);

    return HttpResponse::json(dict[
      'status' => 'written',
      'tuple' => $tuple->toString(),
    ], 201);
  }
}
