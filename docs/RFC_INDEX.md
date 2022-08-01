# Axon Architectural Design Records (ADR / RFC Index)

This document tracks formal architectural design decisions, trade-offs, and design records for the Axon graph execution engine.

---

## Index of Design Records

| RFC ID | Title | Status | Date |
| :--- | :--- | :--- | :--- |
| **RFC-001** | Microtask Queue & DataLoader Batching Design | Accepted | 2026-01-15 |
| **RFC-002** | Zanzibar Userset Rewrite Cycle Termination Guarantee | Accepted | 2026-02-01 |
| **RFC-003** | Adaptive Replacement Cache (ARC) vs 2Q vs LRU Evaluation | Accepted | 2026-02-18 |
| **RFC-004** | Binary Write-Ahead Log Framing with Castagnoli CRC32 | Accepted | 2026-03-05 |
| **RFC-005** | Federated Subgraph Query Decomposition DAG | Accepted | 2026-03-22 |
| **RFC-006** | Hybrid Logical Clock (HLC) Causal Order Guarantees | Accepted | 2026-04-10 |

---

## RFC-001: Microtask Queue & DataLoader Batching Design

### Context
Deeply nested GraphQL selection sets (e.g. `User -> Documents -> Workspaces -> Organizations`) trigger the classic $O(N)$ query fanout problem when evaluated with naive recursive descent.

### Decision
Implement an asynchronous batch coalescing mechanism (`AsyncBatcher`) coupled to request-scoped `DataLoaderRegistry` containers. Keys are enqueued into a pending round buffer and dispatched in bulk.

### Consequences
- Database and cache round-trips drop from $O(N)$ to $O(D)$ where $D$ is the tree depth.
- Eliminates duplicate fetches of identical entities within a single query context.

---

## RFC-002: Zanzibar Userset Rewrite Cycle Termination Guarantee

### Context
Graph authorization rules can contain cyclic dependencies across groups, roles, or organizations (e.g., mutual group membership).

### Decision
Maintain an in-memory call chain state set:

$$S = \{ (o, r, s) \}$$

If a recursive check encounters a state key already present in $S$, evaluation along that branch immediately returns `false` without propagating an exception.

### Consequences
- Guarantees termination in finite steps for all graph configurations.
- Eliminates deadlocks without distributed lock managers.
