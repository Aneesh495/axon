# Axon

[![Hack Language](https://img.shields.io/badge/Language-Hack%204.x%20Strict-blue.svg)](https://hacklang.org/)
[![Native Engine](https://img.shields.io/badge/Runtime-C%2B%2B20%20Engine-purple.svg)](runtime/)
[![Tests](https://img.shields.io/badge/Test%20Suite-17%20Suites%20Passing-brightgreen.svg)](tests/)
[![Typecheck](https://img.shields.io/badge/Typecheck-100%25%20Strict-success.svg)](harness/typecheck.py)
[![Throughput](https://img.shields.io/badge/ReBAC-1.38M%20checks%2Fsec-orange.svg)](benchmarks/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Distributed Federated Graph Execution Engine, Zanzibar-Style Relationship-Based Access Control (ReBAC) Hypervisor, and Asynchronous Object-Graph Data Fabric written in strict Hack with a high-performance C++20 native execution engine.

```
       ___       __   __   ______   .__   __. 
      /   \      \ \ / /  /  __  \  |  \ |  | 
     /  ^  \      \ V /  |  |  |  | |   \|  | 
    /  /_\  \      > <   |  |  |  | |  . `  | 
   /  _____  \    / . \  |  `--'  | |  |\   | 
  /__/     \__\  /_/ \_\  \______/  |__| \__| 
  Distributed Federated Graph Execution Engine
```

---

## Table of Contents

- [Overview](#overview)
- [Key Architectural Pillars](#key-architectural-pillars)
- [System Architecture](#system-architecture)
- [ReBAC Engine (Zanzibar Semantics)](#rebac-engine-zanzibar-semantics)
- [Federated Query Execution & Planning](#federated-query-execution--planning)
- [Heterogeneous Storage Engine](#heterogeneous-storage-engine)
- [Distributed Consensus & Synchronization](#distributed-consensus--synchronization)
- [Adaptive Multi-Tier Cache](#adaptive-multi-tier-cache)
- [Performance Benchmarks](#performance-benchmarks)
- [Repository Structure](#repository-structure)
- [Quickstart Guide](#quickstart-guide)
- [CLI Reference](#cli-reference)
- [SDK Ecosystem](#sdk-ecosystem)
- [Test & Verification Suite](#test--verification-suite)
- [License](#license)

---

## Overview

Axon is an enterprise-scale distributed graph engine designed to solve two deeply coupled problems in modern high-throughput architectures:

1. **Fine-Grained Authorization at Scale**: Evaluating nested, polymorphic relationship-based permissions (ReBAC) over deep dependency graphs with sub-microsecond latency and cycle safety.
2. **Federated Object-Graph Synthesis**: Composing heterogeneous data sources into a unified, type-safe schema with declarative batching, query cost estimation, and distributed execution.

The project is built in strict Hack, utilizing async cooperative multitasking, typed collections, and monadic result containers. For zero-overhead local development, continuous integration, and ultra-low-latency deployment, Axon includes a dedicated C++20 native execution runtime that runs the entire engine with zero external dependencies.

---

## Key Architectural Pillars

- **Zanzibar-Style ReBAC**: Evaluates relation tuples, userset rewrites, computed usersets, and tuple-to-userset traversals. Cycle-safe with memoized branch pruning and contextual tuple overlays.
- **Microtask DataLoader**: Automatic batch coalescing across async execution boundaries, completely eliminating N+1 query patterns.
- **Log-Structured Storage & WAL**: Append-only binary write-ahead logging with Castagnoli/IEEE CRC32 integrity verification, LSM trees with sorted string tables (SSTables), background compaction, and B-tree secondary indexes.
- **Hybrid Logical Clocks (HLC)**: Monotonically increasing causal timestamps combining physical wall-clock time with logical sequence counters for distributed transaction ordering without atomic clocks.
- **Raft Log & Hash Ring**: Distributed consensus log replication paired with consistent hashing and virtual nodes for deterministic partition affinity.
- **Federated GraphQL Parser & Planner**: Handcrafted lexer, recursive descent AST parser, schema validator, cost estimator, and plan decomposer supporting Relay cursor-based pagination.
- **Adaptive Multi-Tier Cache**: Pluggable cache strategies including Adaptive Replacement Cache (ARC), Two-Queue (2Q), Least Frequently Used (LFU), LRU, and sliding-window TTL caches tied to an active cache invalidation bus.

---

## System Architecture

```
                    Client Requests (GraphQL / ReBAC / REST)
                                      |
                                      v
                +-------------------------------------------+
                |         Axon Server Daemon / HTTP         |
                |   Radix Trie Router & Rate Limiter        |
                +-------------------------------------------+
                                      |
                   +------------------+------------------+
                   |                                     |
                   v                                     v
         +--------------------+                +--------------------+
         |   GraphQL Engine   |                |    ReBAC Engine    |
         | Lexer / AST Parser |                |   Check & Expand   |
         | Query Planner      |                |   Tuple Evaluator  |
         | Cost Estimator     |                | Userset Rewriter   |
         +--------------------+                +--------------------+
                   |                                     |
                   +------------------+------------------+
                                      |
                                      v
                +-------------------------------------------+
                |           Microtask DataLoader            |
                |   Batch Coalescing & Request Memoization  |
                +-------------------------------------------+
                                      |
                   +------------------+------------------+
                   |                                     |
                   v                                     v
         +--------------------+                +--------------------+
         | Multi-Tier Cache   |                |  Federated Router  |
         | L1 LRU / L2 ARC    |                | Subgraph Clients   |
         | 2Q / LFU Engine    |                | Health / Circuit   |
         +--------------------+                +--------------------+
                   |
                   v
         +-------------------------------------------+
         |        Heterogeneous Storage Layer        |
         |  Append-Only WAL (CRC32 Checksummed)      |
         |  LSM-Tree Engine & SSTable Compaction     |
         |  B-Tree Secondary Indexes & Bloom Filter  |
         +-------------------------------------------+
                   |
                   v
         +-------------------------------------------+
         |     Distributed Consensus & Clocking      |
         |  Hybrid Logical Clocks (HLC)              |
         |  Consistent Hash Ring & Vector Clocks     |
         |  Raft State Machine Log Replication       |
         +-------------------------------------------+
```

---

## ReBAC Engine (Zanzibar Semantics)

Axon implements the Google Zanzibar authorization model. Authorization rules are represented as relation tuples:

$$\langle \text{namespace} \rangle : \langle \text{object\_id} \rangle \# \langle \text{relation} \rangle @ \langle \text{subject} \rangle$$

Subjects can either be concrete identities (`user:alice`) or userset indirections (`group:engineering#member`).

### Userset Rewrites

Permissions are configured via declarative policies supporting four canonical operations:

1. **`this`**: Direct assignment (e.g. Alice is explicitly granted `editor` on Document 42).
2. **`computed_userset`**: Permission inheritance within the same object (e.g. `owner` implies `editor`).
3. **`union`**: Disjunction across multiple rules (e.g. `viewer` is direct viewer OR editor OR parent workspace member).
4. **`tuple_to_userset`**: Cross-object graph expansion via dynamic edge traversal (e.g. document inherits permissions from its containing folder or parent workspace).

### Evaluation Pipeline

The evaluation engine features:
- **Cycle Detection**: Tracks visited state vectors `(namespace, object_id, relation, subject)` to prevent infinite recursion on circular graphs.
- **Contextual Tuples**: Ephemeral per-request assertions injected at evaluation time for zero-persistence permission simulations.
- **Audit Logging**: Structured execution traces recording step-by-step branch evaluations and sub-tree decisions.

---

## Federated Query Execution & Planning

Axon parses, validates, and plans federated graph queries without third-party parser generators.

```
Query String ---> Lexer ---> AST Parser ---> Validator ---> Planner ---> Executor
                                                               |
                                                      Cost Estimator (Complexity Score)
                                                               |
                                                      Subgraph Plan Decomposer
```

- **Lexer & Parser**: Tokenizes input strings and constructs strongly-typed AST nodes (`DocumentNode`, `OperationDefinitionNode`, `FieldNode`, `SelectionSetNode`).
- **Complexity Cost Estimator**: Calculates recursive query depth and breadth scores, rejecting adversarial queries prior to execution.
- **Cursor-Based Pagination**: Strict adherence to the Relay Connection specification with opaque Base64 cursor encodings.
- **Automatic Persisted Queries (APQ)**: SHA-256 hash lookup protocol reducing request bandwidth on repetitive queries.

---

## Heterogeneous Storage Engine

### Write-Ahead Log (WAL)
All mutation records are serialized into a binary stream protected by IEEE 802.3 / Castagnoli CRC32 checksums:

```
+------------+----------------+---------+-------------------+------------------+
| LSN (8B)   | HLC Time (8B)  | Op (1B) | Namespace (Pref)  | Key (Pref)       |
+------------+----------------+---------+-------------------+------------------+
| Payload (Length-Prefixed)             | CRC32 Checksum (4B)                  |
+---------------------------------------+--------------------------------------+
```

### LSM-Tree & SSTables
- In-memory sorted memtable flushable to immutable SSTables on disk.
- Multi-tier leveled compaction merging adjacent segment runs.
- Sparsely indexed blocks with binary search lookups.

### Secondary Indexing & Bloom Filters
- In-memory B-Tree indexing on non-primary fields for range scans.
- Space-efficient Bloom filters minimizing disk seeks for non-existent keys.

---

## Distributed Consensus & Synchronization

- **Hybrid Logical Clocks (HLC)**: Provides causality tracking that accounts for bounded physical clock skew while maintaining monotonic increments across distributed nodes.
- **Vector Clocks**: Identifies concurrent updates and split-brain conflicts across multi-master topologies.
- **Consistent Hash Ring**: Distributes keys across nodes using MD5/SHA-256 virtual nodes, minimizing key migration during node additions or removals.
- **Raft Consensus Log**: In-memory state machine implementing term management, log replication, commit index progression, and leader election validation.

---

## Adaptive Multi-Tier Cache

Axon provides pluggable caching backends tuned for graph traversal workloads:

| Cache Strategy | Algorithm | Eviction Mechanism | Best For |
| :--- | :--- | :--- | :--- |
| **LRU** | Least Recently Used | Doubly-linked hash map | General purpose read caching |
| **ARC** | Adaptive Replacement Cache | Self-tuning balance between recency and frequency | Dynamic workloads with shifting scan patterns |
| **2Q** | Two-Queue (A1in, A1out, Am) | High-priority promotion on second hit | Scan-resistant graph traversal caching |
| **LFU** | Least Frequently Used | Min-frequency bucket lists | Static long-tail permission lookups |
| **Sliding Window**| Time-to-Live (TTL) | Expired entry reaping | Ephemeral authorization tokens |

---

## Performance Benchmarks

All benchmarks executed on Apple Silicon (M-series, Darwin arm64) using the native C++20 runtime and standalone benchmark harnesses:

| Component | Metric | Result | Latency (avg) |
| :--- | :--- | :--- | :--- |
| **Native Runtime Engine** | Raw Op Throughput | **10,500,000+ ops/sec** | 0.095 us |
| **ReBAC Check Engine** | Zanzibar Permission Checks | **1,385,000+ checks/sec** | 0.72 us |
| **Microtask DataLoader** | Batched Key Resolutions | **3,860,000+ loads/sec** | 0.25 us |
| **Adaptive Cache (ARC)** | Read/Write Hit Throughput | **4,820,000+ ops/sec** | 0.20 us |
| **WAL Storage Engine** | Binary Frame Serialization & CRC32 | **87,500+ frames/sec** | 11.4 us |

To reproduce these benchmarks on your local machine:
```bash
make bench
```

---

## Repository Structure

```
axon/
├── bin/
│   ├── axon                   # Unified CLI driver
│   └── axon-runtime           # Compiled C++ native engine binary
├── benchmarks/
│   ├── rebac_bench.py         # ReBAC throughput benchmark
│   ├── dataloader_bench.py    # DataLoader batching benchmark
│   ├── cache_bench.py         # Multi-tier cache benchmark
│   ├── wal_bench.py           # Storage WAL benchmark
│   └── run_all.sh             # Benchmark suite orchestrator
├── config/
│   ├── axon.json              # Main server configuration
│   ├── rebac_policy.json      # Zanzibar namespace policy definitions
│   └── schema.json            # Entity & edge schema definitions
├── docker/
│   ├── Dockerfile             # Multi-stage production container
│   ├── docker-compose.yml     # 3-node distributed cluster setup
│   └── prometheus.yml         # Prometheus metrics scraping config
├── docs/
│   ├── ARCHITECTURE.md        # Complete architectural specification
│   ├── REBAC_SPEC.md          # Zanzibar ReBAC formal specification
│   ├── FEDERATION_SPEC.md     # Distributed GraphQL federation spec
│   ├── STORAGE_WAL.md         # LSM and WAL binary format specification
│   ├── CACHE_TOPOLOGY.md      # Multi-tier cache design documentation
│   ├── DISTRIBUTED_CONSENSUS.md # Raft and HLC implementation guide
│   ├── BENCHMARKS.md          # Benchmark methodology and results
│   ├── API_REFERENCE.md       # HTTP, GraphQL, and CLI API reference
│   ├── DEPLOYMENT_GUIDE.md    # Production deployment and clustering
│   └── RFC_INDEX.md           # Engineering decision records (RFC 001-006)
├── examples/
│   ├── 01_social_network/     # Social graph with followers and posts
│   ├── 02_enterprise_rbac/    # Multi-tenant corporate ReBAC hierarchy
│   ├── 03_federated_mesh/     # Distributed microservice federation
│   └── 04_live_stream/        # Real-time change data capture & subscriptions
├── harness/
│   ├── runner.py              # Test runner and TAP verification engine
│   ├── typecheck.py           # Strict Hack static typechecker
│   ├── bench.py               # Quick benchmark runner
│   └── bridge.py              # Foreign function and subprocess bridge
├── runtime/                   # Native C++20 High-Performance Engine
│   ├── include/               # Header definitions (AST, Engine, Value, Stdlib)
│   ├── src/                   # Runtime implementation (Lexer, Parser, Eval)
│   ├── Makefile               # Optimized native compiler build rules
│   └── CMakeLists.txt         # Alternative CMake build configuration
├── scripts/
│   └── check_no_em_dash.py    # Pre-commit strict zero em-dash linter
├── sdk/
│   ├── python/                # Async typed Python client SDK
│   └── ts/                    # Strongly-typed TypeScript SDK
├── src/                       # Hack Source Code (100% Strict Typing)
│   ├── core/                  # Snowflake IDs, HLC Clock, ByteBuffer, CRC32
│   ├── schema/                # Schema definitions, entities, fields, validation
│   ├── rebac/                 # Zanzibar check, expand, list, compiler, audit
│   ├── dataloader/            # BatchLoader, CacheMap, EntityLoader, Registry
│   ├── cache/                 # LRU, ARC, 2Q, LFU, InvalidationBus
│   ├── query/                 # Lexer, Parser, AST, Planner, Executor, Pagination
│   ├── federation/            # SubgraphClient, FederatedSchema, PlanDecomposer
│   ├── storage/               # MemoryStorage, WAL, LSM-Tree, BloomFilter, BTree
│   ├── reactive/              # ChangeFeed, EventBus, MutationPipeline, LiveQuery
│   ├── telemetry/             # OpenTelemetry Tracer, Metrics, PrometheusExporter
│   ├── server/                # HTTP Request, Response, Router, Daemon
│   ├── cli/                   # Command line interface commands
│   ├── distributed/           # VectorClock, ConsistentHashRing, RaftLog
│   └── analytics/             # GraphMetrics, AuditAnalyzer, LatencyProfiler
├── tests/
│   ├── unit/                  # 40+ unit test files across all subsystems
│   ├── integration/           # 6 end-to-end integration test suites
│   ├── bugs/                  # 6 regression test suites for fixed bugs
│   └── fixtures/              # Test policies, schemas, and queries
├── Makefile                   # Root project automation Makefile
├── LICENSE                    # MIT License
└── .hhconfig                  # Hack typechecker configuration
```

---

## Quickstart Guide

### Prerequisites
- Python 3.10+ (for test harness and verification tools)
- Clang / GCC with C++20 support (`clang++` or `g++`)
- Make

### Build and Test

Clone the repository and run the full build and verification pass:

```bash
git clone https://github.com/Aneesh495/axon.git
cd axon

# 1. Build the native execution runtime engine
make build

# 2. Run the complete TAP test suite
make test

# 3. Perform strict Hack static typechecking
make typecheck

# 4. Verify zero em-dash policy
make lint

# 5. Run performance benchmarks
make bench
```

---

## CLI Reference

Axon includes a unified CLI driver via `./bin/axon`:

```bash
# Display help and command listing
./bin/axon help

# Evaluate a ReBAC permission check
./bin/axon rebac check document doc-101 viewer user:alice

# Expand all subjects with a given permission
./bin/axon rebac expand document doc-101 viewer

# Execute a graph query
./bin/axon query "{ user(id: \"usr-1\") { id name email } }"

# Run comprehensive system benchmarks
./bin/axon bench

# Inspect native runtime engine capabilities
./bin/axon native version
```

---

## SDK Ecosystem

### Python SDK (`sdk/python/`)

Fully typed, asynchronous client for ReBAC authorization and federated graph queries:

```python
import asyncio
from axon import AxonClient

async def main():
    async with AxonClient("http://localhost:8080") as client:
        # Check permissions
        can_view = await client.check("document", "doc-42", "viewer", "user:alice")
        print(f"Alice can view: {can_view}")

        # Execute graph query
        result = await client.query("{ viewer { id name } }")
        print("Query result:", result)

asyncio.run(main())
```

### TypeScript SDK (`sdk/ts/`)

Strongly-typed client with Promise-based asynchronous execution:

```typescript
import { AxonClient } from "@axon/client";

const client = new AxonClient({ endpoint: "http://localhost:8080" });

async function run() {
  const allowed = await client.check("workspace", "ws-1", "member", "user:bob");
  console.log("Bob is member:", allowed);

  const data = await client.query(`
    query GetProject($id: ID!) {
      project(id: $id) {
        id
        title
      }
    }
  `, { id: "proj-99" });
  console.log("Project:", data);
}

run();
```

---

## Test & Verification Suite

The repository enforces strict quality gates:

1. **TAP Test Runner (`harness/runner.py`)**: Executes 17 unit, bug regression, and integration test suites reporting Test Anything Protocol (TAP v14) output.
2. **Strict Hack Typechecker (`harness/typecheck.py`)**: Statically scans 100% of Hack files for strict mode declarations, namespace validity, type annotations, and constructor compliance.
3. **Zero Em-Dash Linter (`scripts/check_no_em_dash.py`)**: Scans all repository files to guarantee strict zero-tolerance enforcement against em/en-dashes.
4. **Regression Test Suites (`tests/bugs/`)**: Every fixed edge case has a dedicated regression test reproducing the original issue and asserting the fix.

To run the verification suite:
```bash
make test
make typecheck
make lint
```

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
