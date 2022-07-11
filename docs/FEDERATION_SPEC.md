# Axon Federated GraphQL Specification

This document describes the design and protocol mechanics for Axon's distributed subgraph federation and schema composition engine.

---

## 1. Overview

Axon acts as a high-performance federated gateway, consolidating heterogeneous microservice entity graphs into a unified supergraph API without centralizing business logic.

```
                     +---------------------------+
                     |    Client Application     |
                     +-------------+-------------+
                                   | GraphQL Query
                                   v
                     +---------------------------+
                     |    Axon Federated Gateway |
                     |   (PlanDecomposer/Merger) |
                     +----+-------------+----+---+
                          |             |    |
          Sub-query 1     | Sub-query 2 |    | Sub-query 3
     +--------------------+             |    +--------------------+
     |                                  v                         |
     v                        +-------------------+               v
+-------------------+         |  Catalog Service  |         +-------------------+
|  Accounts Service |         |  (Products/SKUs)  |         |  Reviews Service  |
|  (Users/Profiles) |         +-------------------+         |  (Ratings/Feeds)  |
+-------------------+                                       +-------------------+
```

---

## 2. Supergraph Schema Directives

Axon supports standard federated directives:

- `@key(fields: "id")`: Declares an entity's primary lookup key for cross-service resolution.
- `@external`: Marks a field as owned by an upstream subgraph.
- `@provides(fields: "...")`: Declares that an association edge can optimize child field retrieval.
- `@requires(fields: "...")`: Specifies prerequisite fields that must be fetched before an extension field can be resolved.

---

## 3. Query Plan Decomposition

Incoming queries are decomposed into a Directed Acyclic Graph (DAG) of `SubgraphTask` nodes:

1. **Root Extraction**: Identifies the primary entity and its owning subgraph.
2. **Field Partitioning**: Divides requested selection fields into local fields vs remote federated fields.
3. **Key Materialization**: Ensures entity primary keys (`id`) are automatically injected into sub-queries even if omitted by the client.
4. **Parallel Execution**: Dispatches non-dependent subgraph requests concurrently over non-blocking HTTP channels.

---

## 4. Deep Result Stitching

Responses returned by upstream subgraphs are merged by `ResultMerger::merge()`:
- Common entity keys are coalesced into a single JSON object.
- Array fields are concatenated or zipped based on cursor specifications.
- Scalar properties overwrite null representations with materialized upstream data.

---

## 5. Resilience and Circuit Breaking

To protect the supergraph from cascading failures when an upstream service degrades:
- Each registered subgraph maintains a stateful `CircuitBreaker`.
- When consecutive failures exceed `failureThreshold` (default: 5), the circuit trips to `OPEN`.
- While `OPEN`, subsequent requests immediately trigger graceful fallback or error masking without network round-trips.
- After `resetTimeoutSeconds` (default: 30s), the breaker transitions to `HALF_OPEN`, allowing a single canary probe to verify recovery.
