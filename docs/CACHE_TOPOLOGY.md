# Axon Multi-Tier Cache Topology

This document details the multi-tiered caching fabric, eviction algorithms, and invalidation bus mechanics implemented in Axon.

---

## 1. Cache Hierarchy

```
+-------------------------------------------------------------------+
|                     L1 Request Cache                              |
|  - Lifetime: Duration of a single graph query                    |
|  - Scope: Request worker fiber / thread                          |
|  - Complexity: O(1) direct dictionary access                      |
+---------------------------------+---------------------------------+
                                  |
                           (Cache Miss)
                                  v
+-------------------------------------------------------------------+
|                     L2 Shared Process Cache                       |
|  - Lifetime: Persistent across requests                           |
|  - Eviction: ARC (Adaptive Replacement) / 2Q / LRU / LFU         |
|  - Capacity: Configurable (default 65,536 entries)                |
+---------------------------------+---------------------------------+
                                  |
                           (Cache Miss)
                                  v
+-------------------------------------------------------------------+
|                     Storage Engine & Subgraphs                    |
|  - Persistent MVCC Storage / Upstream Federated Microservices    |
+-------------------------------------------------------------------+
```

---

## 2. Eviction Policy Algorithms

### 2.1 Adaptive Replacement Cache (ARC)
Invented by Nimrod Megiddo and Dharmendra S. Modha, ARC dynamically balances between recency and frequency:
- $T_1$: Recent items resident in memory.
- $B_1$: Ghost history of evicted recent keys (no payload, tracking only).
- $T_2$: Frequent items resident in memory.
- $B_2$: Ghost history of evicted frequent keys.
- Tuning parameter $p \in [0, c]$ adapts automatically based on hits in $B_1$ or $B_2$.

### 2.2 Two-Queue (2Q) Cache
2Q provides scan resistance without priority queue overhead:
- Incoming items enter FIFO queue $A1_{\text{in}}$.
- Items evicted from $A1_{\text{in}}$ enter ghost queue $A1_{\text{out}}$.
- Items accessed while in $A1_{\text{out}}$ are promoted into long-term LRU queue $A_m$.

### 2.3 Least Frequently Used (LFU)
Provides true $O(1)$ LFU eviction by maintaining discrete frequency sets with a monotonic `minFreq` tracker.

---

## 3. Invalidation Bus

When an entity or relationship tuple mutates:
1. The mutation pipeline publishes an `InvalidationMessage` containing the entity namespace and primary key.
2. The `InvalidationBus` routes the message to all subscribed worker caches.
3. Matching cache entries are evicted from both L1 and L2 immediately.
