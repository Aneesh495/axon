# Axon Distributed Consensus & Partitioning Specification

This document details the distributed clustering, consistent hashing, causal vector clocks, and Raft consensus mechanisms in Axon.

---

## 1. Virtual Node Consistent Hashing

Axon partitions entities across shards using consistent hashing with virtual nodes (vnodes):

- Each physical cluster node is assigned $K$ virtual tokens along a 32-bit circular ring ($K = 100$ by default).
- The hash of an entity identifier $h(k) \in [0, 2^{32} - 1]$ maps to the first virtual node token encountered in clockwise order.
- Adding or removing a physical shard relocates only $\frac{1}{N}$ fraction of keys, minimizing reshuffle during cluster expansion.

---

## 2. Causal Vector Clocks

To support multi-region replication and distributed conflict detection without clock synchronization assumptions, Axon assigns a Vector Clock to each mutation:

$$V = \{ \text{node}_i \mapsto c_i \}$$

### Causal Ordering Rules

Given two vector clocks $V_1$ and $V_2$:

1. $V_1 = V_2 \iff \forall k, V_1[k] = V_2[k]$ (Equal)
2. $V_1 \le V_2 \iff \forall k, V_1[k] \le V_2[k]$
3. $V_1 < V_2 \iff V_1 \le V_2 \land \exists k, V_1[k] < V_2[k]$ (Strictly Before)
4. $V_1 \parallel V_2 \iff \neg(V_1 \le V_2) \land \neg(V_2 \le V_1)$ (Concurrent Conflict)

When a concurrent conflict is detected, the engine flags the record for application-level resolution or deterministic LWW (Last-Write-Wins) based on Hybrid Logical Clock (HLC) timestamps.

---

## 3. Replicated Raft Consensus Log

Metadata, namespace schemas, and global relationship tuples are synchronized across cluster peers using a Raft consensus log:
- **Leader Election**: Heartbeat timeouts trigger randomized election timers.
- **Log Matching Property**: If two entries in different logs have the same index and term, they store the same command.
- **Commit Boundary**: Entries are committed once replicated across a strict majority quorum ($Q = \lfloor \frac{N}{2} \rfloor + 1$).
